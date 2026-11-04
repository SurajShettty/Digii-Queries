-- Employee Workload report (CHEDS/KHDA format).
-- One row per staff (faculty / administrator) user for the selected academic period:
--   * every user who taught a class in that period (class_faculty, substitutes excluded), and
--   * every other active staff user (non-teaching staff get 0 teaching figures).
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (CHEDS Semester Code list)
-- Filter: {{academic_period}} = Academic Period code from academic_period_filter.sql, e.g. 202510.
-- Teaching figures are counted per course, not per class: the lecture / tutorial / practical classes of one course taught
--   by a faculty member in a period count as one course, and its students are the distinct students across those classes.
--   Course credits = term course snapshot, else term / default course version, else course; credits > 0 -> credited course.
--   Teaching Workload = sum of credits of the credited courses taught; Credits Delivered = sum of credits x students.
-- Programme of a class: mapped programme batch sections, else programmes of the students added to the class, else the
--   class's / term's programme (same logic as the Course Faculty report).
-- KHDA codes come from khda_sync (the inner query r returns the Digii values, the outer query maps them):
--   digii_code_map  = confirmed Digii value -> KHDA code per KHDA tenant (khda_code; suggested_code is ignored until confirmed);
--                     kind = the master_value list name below, digii_id = the Digii value
--   institution     = KHDA tenant -> Digii college (digii_data_college_id, else digii_college_id)
--   master_value    = KHDA code lists; mapped codes must exist here
--   Each coded column = confirmed mapping, else a direct label / code match in master_value, else the default:
--     Full or Part Time  list 'fullparttime'     default 'FT'
--     Employee Category  list 'facultycategory'  default faculty -> 'A' (full-time instructional) / 'B' (part-time instructional),
--                                                 administrator -> 'D' (administrative officers)
--     Employee position  list 'staffposition'    default 'OTH' (Others)
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet; spec defaults are used where the spec gives one.
-- MySQL 5.x compatible: no CTEs / window functions. khda_sync uses a different collation, hence the explicit COLLATE.
SELECT
    r.`Institution Code`,
    r.`Institution Name`,
    r.`Academic Period`,
    r.`Employee ID`,
    r.`Program Level`,
    r.`Employee Area of Specialization (CIP Family code)`,
    r.`Department name`,
    COALESCE(
        (SELECT mv.code
         FROM khda_sync.digii_code_map m
         JOIN khda_sync.institution i   ON i.tenant_id = m.tenant_id
         JOIN khda_sync.master_value mv ON mv.list_name = 'facultycategory' AND mv.code = m.khda_code COLLATE utf8mb4_unicode_ci
         WHERE COALESCE(i.digii_data_college_id, i.digii_college_id) = r.college_id
           AND m.kind = 'facultycategory' AND m.digii_id COLLATE utf8mb4_unicode_ci = r.raw_category
         LIMIT 1),
        (SELECT mv.code FROM khda_sync.master_value mv
         WHERE mv.list_name = 'facultycategory' AND r.raw_category IN (mv.label, mv.code) LIMIT 1),
        CASE WHEN r.user_type = 'administrator' THEN 'D'
             WHEN r.full_part_time = 'PT'       THEN 'B'
             ELSE 'A' END)                                              AS `Employee Category`,         -- EXCH_IN_OUT not captured (Enhancement Required)
    r.full_part_time                                                    AS `Full or Part Time`,
    COALESCE(
        (SELECT mv.code
         FROM khda_sync.digii_code_map m
         JOIN khda_sync.institution i   ON i.tenant_id = m.tenant_id
         JOIN khda_sync.master_value mv ON mv.list_name = 'staffposition' AND mv.code = m.khda_code COLLATE utf8mb4_unicode_ci
         WHERE COALESCE(i.digii_data_college_id, i.digii_college_id) = r.college_id
           AND m.kind = 'staffposition' AND m.digii_id COLLATE utf8mb4_unicode_ci = r.raw_position
         LIMIT 1),
        (SELECT mv.code FROM khda_sync.master_value mv
         WHERE mv.list_name = 'staffposition' AND r.raw_position IN (mv.label, mv.code) LIMIT 1),
        'OTH')                                                          AS `Employee position`,
    r.`Additional Position`,
    r.`Maximum Workload per semester`,
    r.`Research Workload`,
    r.`Admin Workload (Career Advising)`,
    r.`Other Admin Workload`,
    r.`Teaching Workload`,
    r.`EXCH_IN_OUT`,
    r.`EXCH Institution Code`,
    r.`EXCH Institution name`,
    r.`EXCH Institution country code`,
    r.`Credits Delivered`,
    r.`Total Credited Courses`,
    r.`Total Non-Credited Course Sections`,
    r.`Total Credited Students`,
    r.`Total Non-Credited Students`,
    r.`Department Joining Date`,
    r.`Linked Programs`,
    r.`Faculty Publications`,
    r.`Faculty FWCI`,
    r.`Last Updated`
FROM (
SELECT
    p.*,
    COALESCE(
        (SELECT mv.code
         FROM khda_sync.digii_code_map m
         JOIN khda_sync.institution i   ON i.tenant_id = m.tenant_id
         JOIN khda_sync.master_value mv ON mv.list_name = 'fullparttime' AND mv.code = m.khda_code COLLATE utf8mb4_unicode_ci
         WHERE COALESCE(i.digii_data_college_id, i.digii_college_id) = p.college_id
           AND m.kind = 'fullparttime' AND m.digii_id COLLATE utf8mb4_unicode_ci = p.raw_full_part_time
         LIMIT 1),
        (SELECT mv.code FROM khda_sync.master_value mv
         WHERE mv.list_name = 'fullparttime' AND p.raw_full_part_time IN (mv.label, mv.code) LIMIT 1),
        'FT')                                                           AS full_part_time
FROM (
SELECT
    c.college_id,
    ua.user_type,
    c.university_code                                                   AS `Institution Code`,          -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    w.academic_period                                                   AS `Academic Period`,
    ua.registration_id                                                  AS `Employee ID`,
    COALESCE(pl.program_level, '99')                                    AS `Program Level`,             -- Program level code to be mapped (CHEDS Program Level list); 99 = no teaching (research / support staff). GE not identified
    NULL                                                                AS `Employee Area of Specialization (CIP Family code)`, -- Enhancement Required (CHEDS CIP Family code; 99 for undeclared)
    d.department_name                                                   AS `Department name`,
    CONVERT(NULLIF(TRIM(pd.staff_category), '') USING utf8mb4) COLLATE utf8mb4_unicode_ci AS raw_category,
    CONVERT(COALESCE(NULLIF(TRIM(pd.employment_type), ''),
                     NULLIF(TRIM(pd.employment_status), '')) USING utf8mb4) COLLATE utf8mb4_unicode_ci AS raw_full_part_time,
    CONVERT(COALESCE(NULLIF(TRIM(dg.name), ''),
                     NULLIF(TRIM(COALESCE(fp.designation, ap.designation)), ''),
                     NULLIF(TRIM(pd.exact_designation), '')) USING utf8mb4) COLLATE utf8mb4_unicode_ci AS raw_position,
    NULL                                                                AS `Additional Position`,       -- Enhancement Required (optional, open text)
    w.teaching_workload                                                 AS `Maximum Workload per semester`, -- To Be Checked: no workload policy captured; defaults to Teaching + Research + Admin workload
    0                                                                   AS `Research Workload`,         -- Enhancement Required (spec default 0)
    0                                                                   AS `Admin Workload (Career Advising)`, -- Enhancement Required (spec default 0)
    0                                                                   AS `Other Admin Workload`,      -- Enhancement Required (spec default 0)
    w.teaching_workload                                                 AS `Teaching Workload`,
    NULL                                                                AS `EXCH_IN_OUT`,               -- Enhancement Required (IN / OT)
    NULL                                                                AS `EXCH Institution Code`,     -- Enhancement Required (mandatory when EXCH_IN_OUT is set)
    NULL                                                                AS `EXCH Institution name`,     -- Enhancement Required (mandatory when EXCH_IN_OUT is set)
    NULL                                                                AS `EXCH Institution country code`, -- Enhancement Required (mandatory when EXCH_IN_OUT is set)
    w.credits_delivered                                                 AS `Credits Delivered`,
    w.credited_courses                                                  AS `Total Credited Courses`,
    w.non_credited_courses                                              AS `Total Non-Credited Course Sections`,
    w.credited_students                                                 AS `Total Credited Students`,   -- clinical-hour proration among faculty not applied
    w.non_credited_students                                             AS `Total Non-Credited Students`,
    COALESCE(NULLIF(TRIM(pd.date_of_joining), ''),
             NULLIF(TRIM(pd.staff_joining_date), ''))                   AS `Department Joining Date`,
    pl.program_codes                                                    AS `Linked Programs`,           -- Program codes to be mapped (program master)
    COALESCE(pub.publications, 0)                                       AS `Faculty Publications`,      -- To Be Checked: ePortfolio journal publications (Scopus indexing not captured)
    0                                                                   AS `Faculty FWCI`,              -- Enhancement Required (spec: 0 for non-faculty)
    DATE_FORMAT(GREATEST(COALESCE(w.last_updated, '1970-01-01'),
                         COALESCE(ua.updated_timestamp, '1970-01-01'),
                         COALESCE(fp.modified_timestamp, ap.modified_timestamp, '1970-01-01'),
                         COALESCE(pd.last_updated, '1970-01-01')), '%Y-%m-%d') AS `Last Updated`
FROM (
    -- workload per user and academic period
    SELECT
        x.ukid,
        x.academic_period,
        ROUND(COALESCE(SUM(CASE WHEN x.credits > 0 THEN x.credits END), 0), 2)              AS teaching_workload,
        ROUND(COALESCE(SUM(CASE WHEN x.credits > 0 THEN x.credits * x.students END), 0), 2) AS credits_delivered,
        COUNT(DISTINCT CASE WHEN x.credits > 0 THEN x.course_id END)                         AS credited_courses,
        COUNT(DISTINCT CASE WHEN x.credits = 0 THEN x.course_id END)                         AS non_credited_courses,
        COALESCE(SUM(CASE WHEN x.credits > 0 THEN x.students END), 0)                        AS credited_students,
        COALESCE(SUM(CASE WHEN x.credits = 0 THEN x.students END), 0)                        AS non_credited_students,
        MAX(x.last_updated)                                                                  AS last_updated
    FROM (
        -- one row per faculty + academic period + course taught
        SELECT
            cf.faculty_id                                               AS ukid,
            t.acad_year_start * 100 + t.sequence * 10                   AS academic_period,
            cl.course_id,
            MAX(COALESCE(tc.course_credits, tcv.course_credits, dcv.course_credits, co.course_credits, 0)) AS credits,
            COUNT(DISTINCT cs.ukid)                                     AS students,
            MAX(GREATEST(cf.modified_timestamp, cl.modified_timestamp)) AS last_updated
        FROM class_faculty cf
        JOIN class cl                    ON cl.id = cf.class_id
        JOIN term t                      ON t.id = cl.term_id
        LEFT JOIN course co              ON co.course_id = cl.course_id
        LEFT JOIN term_course tc         ON tc.term_id = cl.term_id AND tc.course_id = cl.course_id
        LEFT JOIN course_version tcv     ON tcv.id = tc.course_version_id
        LEFT JOIN course_version dcv     ON dcv.course_id = cl.course_id AND dcv.is_default = 1
        LEFT JOIN class_student cs       ON cs.class_id = cl.id
        WHERE IFNULL(cf.is_substitute, 0) = 0
          AND cl.course_id IS NOT NULL
          AND t.acad_year_start * 100 + t.sequence * 10 = {{academic_period}}
        GROUP BY cf.faculty_id, academic_period, cl.course_id

        UNION ALL

        -- selected academic period row for every active staff user
        SELECT
            ua.ukid,
            {{academic_period}},
            NULL, NULL, NULL, NULL
        FROM user_attributes ua
        JOIN authenticator a ON a.ukid = ua.ukid AND a.is_active = 1
        WHERE ua.user_type IN ('faculty', 'administrator')
    ) x
    GROUP BY x.ukid, x.academic_period
) w
JOIN user_attributes ua               ON ua.ukid = w.ukid AND ua.user_type IN ('faculty', 'administrator')
LEFT JOIN faculty_profile fp          ON fp.ukid = ua.ukid AND ua.user_type = 'faculty'
LEFT JOIN admin_profile ap            ON ap.ukid = ua.ukid AND ua.user_type = 'administrator'
LEFT JOIN college c                   ON c.college_id = ua.college_id
LEFT JOIN department d                ON d.department_id = COALESCE(fp.department_id, ap.department_id)
LEFT JOIN designation dg              ON dg.id = COALESCE(fp.designation_id, ap.designation_id)
LEFT JOIN (
    -- programme level (level with the most students, ties -> more advanced level) and linked programme codes
    SELECT
        lv.ukid,
        lv.academic_period,
        SUBSTRING_INDEX(GROUP_CONCAT(lv.level_name ORDER BY lv.students DESC, lv.level_rank DESC SEPARATOR '|'), '|', 1) AS program_level,
        GROUP_CONCAT(lv.program_codes ORDER BY lv.level_rank DESC SEPARATOR '; ')                                        AS program_codes
    FROM (
        SELECT
            cf.faculty_id                                               AS ukid,
            t.acad_year_start * 100 + t.sequence * 10                   AS academic_period,
            pt.name                                                     AS level_name,
            CASE pt.name WHEN 'PhD'           THEN 5
                         WHEN 'Post-Graduate' THEN 4
                         WHEN 'Undergraduate' THEN 3
                         WHEN 'Diploma'       THEN 2
                         WHEN 'Certificate'   THEN 1
                         ELSE 0 END                                     AS level_rank,
            COUNT(DISTINCT cs.ukid)                                     AS students,
            GROUP_CONCAT(DISTINCT p.programme_code ORDER BY p.programme_code SEPARATOR '; ') AS program_codes
        FROM class_faculty cf
        JOIN class cl                    ON cl.id = cf.class_id
        JOIN term t                      ON t.id = cl.term_id
        LEFT JOIN (
            SELECT class_id, programme_id
            FROM class_programme_batch_sections
            WHERE programme_id IS NOT NULL
            UNION
            SELECT cs.class_id, sp.programme_id
            FROM class_student cs
            JOIN student_profile sp ON sp.ukid = cs.ukid
            WHERE sp.programme_id IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM class_programme_batch_sections b
                              WHERE b.class_id = cs.class_id AND b.programme_id IS NOT NULL)
        ) cps                            ON cps.class_id = cl.id
        JOIN programme p                 ON p.programme_id = COALESCE(cps.programme_id, cl.programme_id, t.programme_id)
        JOIN programme_types pt          ON pt.id = p.programme_type_id
        LEFT JOIN class_student cs       ON cs.class_id = cl.id
        WHERE IFNULL(cf.is_substitute, 0) = 0
          AND t.acad_year_start * 100 + t.sequence * 10 = {{academic_period}}
        GROUP BY cf.faculty_id, academic_period, pt.name
    ) lv
    GROUP BY lv.ukid, lv.academic_period
) pl ON pl.ukid = w.ukid AND pl.academic_period = w.academic_period
LEFT JOIN (
    -- single-entry ePortfolio fields (employment)
    SELECT
        v.ukid,
        MAX(CASE WHEN f.identifier = 'STAFF_CATEGORY'     THEN COALESCE(li.name, v.value) END) AS staff_category,
        MAX(CASE WHEN f.identifier = 'EMPLOYMENT_TYPE'    THEN COALESCE(li.name, v.value) END) AS employment_type,
        MAX(CASE WHEN f.identifier = 'EMPLOYMENT_STATUS'  THEN v.value END)                    AS employment_status,
        MAX(CASE WHEN f.identifier = 'EXACT_DESIGNATION'  THEN v.value END)                    AS exact_designation,
        MAX(CASE WHEN f.identifier = 'DATE_OF_JOINING'    THEN v.value END)                    AS date_of_joining,
        MAX(CASE WHEN f.identifier = 'STAFF_JOINING_DATE' THEN v.value END)                    AS staff_joining_date,
        MAX(v.modified_timestamp)                                                              AS last_updated
    FROM user_details_master_field_value v
    JOIN user_details_master_field f                ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id
                                                    AND li.id = v.value
    WHERE f.identifier IN ('STAFF_CATEGORY', 'EMPLOYMENT_TYPE', 'EMPLOYMENT_STATUS', 'EXACT_DESIGNATION',
                           'DATE_OF_JOINING', 'STAFF_JOINING_DATE')
      AND NULLIF(TRIM(v.value), '') IS NOT NULL
    GROUP BY v.ukid
) pd ON pd.ukid = ua.ukid
LEFT JOIN (
    -- journal publication entries in ePortfolio
    SELECT v.ukid, COUNT(DISTINCT v.cluster_entry_id) AS publications
    FROM user_details_master_cluster_entry_field_value v
    JOIN user_details_master_field f    ON f.id = v.field_id
    JOIN user_details_master_cluster mc ON mc.id = f.cluster_id AND mc.identifier = 'JOURNAL_PUBLICATION_DETAILS'
    WHERE NULLIF(TRIM(v.value), '') IS NOT NULL
    GROUP BY v.ukid
) pub ON pub.ukid = ua.ukid
) p
) r
ORDER BY r.`Institution Name`, r.`Department name`, r.`Employee ID`;
