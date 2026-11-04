-- Applicants - Basic Details report (CHEDS/KHDA format).
-- One row per institution + admission academic period + KHDA degree code + KHDA area of specialisation (CIP family) code.
-- Grain of an application = student_admission_form_status (one row per applicant per admission category = programme + batch + quota).
--   Number of Applicants          = all applications that reached the admissions team for a decision
--   Number of Admissions Offered  = applications in Provisional Allotment / Registered Student, or with a released admission offer letter
--   Number of New Enrollments     = applications in Registered Student (status ACCEPTED, i.e. converted to student)
-- Academic periods are coded as <acad_year_start><term sequence>0 of the first term of the admitted batch, e.g. 2025-26 term 1 -> 202510;
-- batches with no term configured fall back to <batch>10. To be mapped (CHEDS Semester Code list)
-- KHDA codes come from khda_sync:
--   digii_code_map  = confirmed Digii value -> KHDA code mapping per KHDA tenant (khda_code; suggested_code is ignored until confirmed)
--   institution     = KHDA tenant -> Digii college (digii_data_college_id, else digii_college_id)
--   master_value    = KHDA code lists ('degreeorprogramlevel', 'areaofspecialization'); mapped codes must exist here
--   Degree:  digii_code_map kind 'degree' (by programme_types.id) or 'degreeorprogramlevel' (by programme type name),
--            else a direct label / code match in master_value, else 'UD' (Undeclared).
--   Area:    digii_code_map kind 'areaofspecialization' (by programme name), else a direct label match in master_value,
--            else '99' (Not listed) per the KHDA rule.
--   Programmes that map to the same codes are summed into one row.
-- Filter: {{academic_period}} = Academic Period code from academic_period_filter.sql, e.g. 202510.
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet.
-- MySQL 5.x compatible: no CTEs / window functions. khda_sync uses a different collation, hence the explicit COLLATE.
SELECT
    x.`Institution Code`,
    x.`Institution Name`,
    x.`Academic Period`,
    x.`Degrees / Program Levels`,
    x.`Area of Specialization`,
    SUM(x.applicants)                                                   AS `Number of Applicants`,
    SUM(x.offered)                                                      AS `Number of Admissions Offered`,
    SUM(x.enrolled)                                                     AS `Number of New Enrollments`,
    MAX(x.last_updated)                                                 AS `Last Updated`
FROM (
    SELECT
        c.college_id,
        c.university_code                                               AS `Institution Code`,          -- CHEDS institution code to be mapped (KHDA Dict)
        c.college_name                                                  AS `Institution Name`,
        COALESCE(
            (SELECT t.acad_year_start * 100 + t.sequence * 10           -- first regular term of the admitted batch (programme term preferred over all-programme term)
             FROM term t
             WHERE t.acad_year_start = sac.batch
               AND IFNULL(t.additional_term, 0) = 0
               AND (t.programme_id = sac.programme_id OR (t.all_programmes = 1 AND t.college_id = sac.college_id))
             ORDER BY (t.programme_id = sac.programme_id) DESC, t.starts
             LIMIT 1),
            sac.batch * 100 + 10)                                       AS `Academic Period`,
        COALESCE(
            (SELECT mv.code                                             -- confirmed mapping (by type id first, then by type name)
             FROM khda_sync.digii_code_map m
             JOIN khda_sync.institution i   ON i.tenant_id = m.tenant_id
             JOIN khda_sync.master_value mv ON mv.list_name = 'degreeorprogramlevel'
                                           AND mv.code COLLATE utf8mb4_unicode_ci = m.khda_code COLLATE utf8mb4_unicode_ci
             WHERE COALESCE(i.digii_data_college_id, i.digii_college_id) = c.college_id
               AND ((m.kind = 'degree' AND m.digii_id COLLATE utf8mb4_unicode_ci = CAST(pt.id AS CHAR) COLLATE utf8mb4_unicode_ci)
                    OR (m.kind = 'degreeorprogramlevel'
                        AND m.digii_id COLLATE utf8mb4_unicode_ci = CONVERT(pt.name USING utf8mb4) COLLATE utf8mb4_unicode_ci))
             ORDER BY (m.kind = 'degree') DESC
             LIMIT 1),
            (SELECT mv.code                                             -- Digii name already equals a KHDA label / code
             FROM khda_sync.master_value mv
             WHERE mv.list_name = 'degreeorprogramlevel'
               AND CONVERT(pt.name USING utf8mb4) COLLATE utf8mb4_unicode_ci IN (mv.label, mv.code)
             LIMIT 1),
            'UD')                                                       AS `Degrees / Program Levels`,  -- 'UD' = Undeclared
        COALESCE(
            (SELECT mv.code                                             -- confirmed mapping by programme name
             FROM khda_sync.digii_code_map m
             JOIN khda_sync.institution i   ON i.tenant_id = m.tenant_id
             JOIN khda_sync.master_value mv ON mv.list_name = 'areaofspecialization'
                                           AND mv.code COLLATE utf8mb4_unicode_ci = m.khda_code COLLATE utf8mb4_unicode_ci
             WHERE COALESCE(i.digii_data_college_id, i.digii_college_id) = c.college_id
               AND m.kind = 'areaofspecialization'
               AND m.digii_id COLLATE utf8mb4_unicode_ci = p.programme_name COLLATE utf8mb4_unicode_ci
             LIMIT 1),
            (SELECT mv.code                                             -- programme name already equals a CIP family label
             FROM khda_sync.master_value mv
             WHERE mv.list_name = 'areaofspecialization'
               AND mv.label = p.programme_name COLLATE utf8mb4_unicode_ci
             LIMIT 1),
            '99')                                                       AS `Area of Specialization`,    -- '99' = Not listed
        COUNT(*)                                                        AS applicants,
        SUM(afs.status IN ('PROVISIONAL_ALLOTMENT', 'ACCEPTED')
            OR IFNULL(ol.has_offer, 0) = 1)                             AS offered,
        SUM(afs.status = 'ACCEPTED')                                    AS enrolled,
        DATE_FORMAT(MAX(GREATEST(s.modified_timestamp,
                                 COALESCE(ol.last_modified, s.modified_timestamp))), '%Y-%m-%d') AS last_updated
    FROM student_admission_form_status s
    JOIN student_admission_category sac   ON sac.id = s.student_admission_category_id
    JOIN programme p                      ON p.programme_id = sac.programme_id
    LEFT JOIN programme_types pt          ON pt.id = p.programme_type_id
    LEFT JOIN admission_form_status afs   ON afs.id = s.status_id
    LEFT JOIN college c                   ON c.college_id = sac.college_id
    LEFT JOIN (
        -- applications for which an admission offer letter was released (accepted / rejected / expired imply it was released)
        SELECT ukid, student_admission_category_id, 1 AS has_offer, MAX(modified_timestamp) AS last_modified
        FROM admission_offer_letter
        WHERE status <> 'NOT_RELEASED'
        GROUP BY ukid, student_admission_category_id
    ) ol ON ol.ukid = s.ukid AND ol.student_admission_category_id = s.student_admission_category_id
    GROUP BY c.college_id, c.university_code, c.college_name, `Academic Period`, pt.id, pt.name, p.programme_id, p.programme_name
    HAVING `Academic Period` = {{academic_period}}
) x
GROUP BY x.college_id, x.`Institution Code`, x.`Institution Name`, x.`Academic Period`,
         x.`Degrees / Program Levels`, x.`Area of Specialization`
ORDER BY x.`Degrees / Program Levels`, x.`Area of Specialization`;
