-- Employee Workload report (CHEDS/KHDA format).
-- One row per staff (faculty / administrator) user per academic period:
--   * every period in which the user taught a class (class_faculty, substitutes excluded), and
--   * the current academic period for every active staff user (non-teaching staff get 0 teaching figures).
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510; the current period uses
--   the same coding with the academic year starting in September (Sep-Dec -> 10, Jan-May -> 20, Jun-Aug -> 30).
--   To be mapped (CHEDS Semester Code list)
-- Teaching figures are counted per course, not per class: the lecture / tutorial / practical classes of one course taught
--   by a faculty member in a period count as one course, and its students are the distinct students across those classes.
--   Course credits = term course snapshot, else term / default course version, else course; credits > 0 -> credited course.
--   Teaching Workload = sum of credits of the credited courses taught; Credits Delivered = sum of credits x students.
-- Programme of a class: mapped programme batch sections, else programmes of the students added to the class, else the
--   class's / term's programme (same logic as the Course Faculty report).
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet; spec defaults are used where the spec gives one.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,          -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    w.academic_period                                                   AS `Academic Period`,
    ua.registration_id                                                  AS `Employee ID`,
    COALESCE(pl.program_level, '99')                                    AS `Program Level`,             -- Program level code to be mapped (CHEDS Program Level list); 99 = no teaching (research / support staff). GE not identified
    NULL                                                                AS `Employee Area of Specialization (CIP Family code)`, -- Enhancement Required (CHEDS CIP Family code; 99 for undeclared)
    d.department_name                                                   AS `Department name`,
    COALESCE(NULLIF(TRIM(pd.staff_category), ''),
             CASE ua.user_type WHEN 'faculty' THEN 'Faculty' ELSE 'Staff' END) AS `Employee Category`, -- To Be Checked: map to CHEDS Faculty Category list (EXCH_IN_OUT not blank -> 'A')
    COALESCE(NULLIF(TRIM(pd.employment_type), ''),
             NULLIF(TRIM(pd.employment_status), ''))                    AS `Full or Part Time`,         -- To Be Checked: map to FT / PT
    COALESCE(NULLIF(TRIM(dg.name), ''),
             NULLIF(TRIM(COALESCE(fp.designation, ap.designation)), ''),
             NULLIF(TRIM(pd.exact_designation), ''))                    AS `Employee position`,         -- Position code to be mapped (CHEDS Position list)
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
        GROUP BY cf.faculty_id, academic_period, cl.course_id

        UNION ALL

        -- current academic period placeholder for every active staff user
        SELECT
            ua.ukid,
            (YEAR(CURDATE()) - (MONTH(CURDATE()) < 9)) * 100
              + CASE WHEN MONTH(CURDATE()) >= 9 THEN 10
                     WHEN MONTH(CURDATE()) <= 5 THEN 20
                     ELSE 30 END,
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
ORDER BY `Academic Period` DESC, `Institution Name`, `Department name`, `Employee ID`;
