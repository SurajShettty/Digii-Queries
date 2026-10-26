-- Student Attrition report (CHEDS/KHDA format).
-- One row per leaver = student with a custom student status set on the profile (Student Management -> Change Status),
-- e.g. Withdrawn / Dropout / Debarred / Transfer / Term break, who has not been converted to alumni (graduates are excluded).
-- The status change is not versioned, so the current status and its remark are reported.
-- Last Academic Period = last term in which the student was enrolled in courses.
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (KHDA Dict)
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,              -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    (SELECT t.acad_year_start * 100 + t.sequence * 10                   -- term running on the report date (programme term preferred over all-programme term)
     FROM term t
     WHERE CURDATE() BETWEEN DATE(t.starts) AND DATE(t.ends)
       AND (t.programme_id = p.programme_id OR (t.all_programmes = 1 AND t.college_id = c.college_id))
     ORDER BY (t.programme_id = p.programme_id) DESC, t.starts DESC
     LIMIT 1)                                                           AS `Submission Term`,
    lt.period_code                                                      AS `Last Academic Period`,
    COALESCE(NULLIF(TRIM(sp.registration_id), ''), ua.registration_id)  AS `Student ID`,
    '999999999999999'                                                   AS `Emirates ID`,                   -- Enhancement Required (999999999999999 when not available)
    TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''),
                        NULLIF(TRIM(ua.m_name), ''),
                        NULLIF(TRIM(ua.l_name), '')))                   AS `Student Name (English)`,
    NULL                                                                AS `Student Name (Arabic)`,         -- Enhancement Required (blank when not available)
    CASE LOWER(sp.gender)
         WHEN 'male'   THEN 'M'
         WHEN 'female' THEN 'F'
         ELSE 'U'
    END                                                                 AS `Gender`,
    DATE_FORMAT(sp.date_of_birth, '%Y-%m-%d')                           AS `Student DOB`,
    COALESCE(NULLIF(TRIM(sp.nationality), ''), cf.nationality,
             NULLIF(TRIM(sp.citizenship), ''))                          AS `Nationality`,                   -- Nationality code to be mapped (KHDA Dict)
    pt.name                                                             AS `Student Level (Level Code)`,    -- Student level code to be mapped (KHDA Dict, e.g. FR)
    NULL                                                                AS `Area of Specialization (CIP Family code)`, -- Enhancement Required ('99' for unclassified programmes)
    p.programme_code                                                    AS `Program (Program Code)`,        -- Program code to be mapped (KHDA Dict)
    ss.name                                                             AS `Attrition Category`,            -- custom student status; Leaver Category code to be mapped (KHDA Dict, e.g. VW / TR)
    COALESCE(NULLIF(TRIM(sp.student_status_remark), ''),
             cf.leaving_reason,
             NULLIF(TRIM(ss.description), ''))                          AS `Attrition Reason`,              -- status change remark; Leaver Reason code to be mapped (KHDA Dict)
    NULL                                                                AS `Withdrawn Credit Hours`,        -- Enhancement Required (course withdrawal is not captured; 0 if none)
    COALESCE(cr.absence_credits, 0)                                     AS `Credit Hours Exceeding 15% Absence Limit`, -- To Be Checked: courses failing the configured attendance eligibility in the last period
    DATE_FORMAT(COALESCE(sp.modified_timestamp, sp.updated_timestamp,
                         sp.last_modified), '%Y-%m-%d')                 AS `Last Updated`
FROM student_profile sp
JOIN student_status ss           ON ss.id = sp.student_status_id
JOIN user_attributes ua          ON ua.ukid = sp.ukid
LEFT JOIN college c              ON c.college_id = COALESCE(sp.college_id, ua.college_id)
LEFT JOIN programme p            ON p.programme_id = sp.programme_id
LEFT JOIN programme_types pt     ON pt.id = p.programme_type_id
LEFT JOIN (
    -- student profile custom fields; list fields store the list item id
    SELECT v.ukid,
           MAX(CASE WHEN f.identifier = 'NATIONALITY' THEN NULLIF(TRIM(v.value), '') END)                    AS nationality,
           MAX(CASE WHEN f.identifier = 'STUDENT_REASON_FOR_LEAVING_UNIVERSITY_STATUS_LIST' THEN li.name END) AS leaving_reason
    FROM user_details_master_field_value v
    JOIN student_profile sp2                        ON sp2.ukid = v.ukid AND sp2.student_status_id IS NOT NULL
    JOIN user_details_master_field f                ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id AND li.id = v.value
    WHERE f.identifier IN ('NATIONALITY', 'STUDENT_REASON_FOR_LEAVING_UNIVERSITY_STATUS_LIST')
    GROUP BY v.ukid
) cf ON cf.ukid = sp.ukid
LEFT JOIN (
    -- last term in which the student was enrolled in courses (exam programme enrolment with enrolled courses)
    SELECT et.ukid,
           CAST(SUBSTRING(MAX(CONCAT(DATE_FORMAT(et.starts, '%Y%m%d'), LPAD(et.term_id, 10, '0'))), 9) AS UNSIGNED) AS term_id,
           CAST(SUBSTRING(MAX(CONCAT(DATE_FORMAT(et.starts, '%Y%m%d'), et.period_code)), 9) AS UNSIGNED)            AS period_code
    FROM (
        SELECT DISTINCT spe.ukid, t.id AS term_id, t.starts,
               t.acad_year_start * 100 + t.sequence * 10 AS period_code
        FROM ems_student_programme_enrollment spe
        JOIN student_profile sp3 ON sp3.ukid = spe.ukid AND sp3.student_status_id IS NOT NULL
        JOIN ems_examination ee  ON ee.id = spe.exam_id
        JOIN term t              ON t.id = ee.term_id
        WHERE EXISTS (SELECT 1
                      FROM ems_student_course_enrollment sce
                      WHERE sce.student_programme_enrollment_id = spe.id
                        AND sce.enrollment_status IN ('ENROLLED', 'AUTO_ENROLLED'))
    ) et
    GROUP BY et.ukid
) lt ON lt.ukid = sp.ukid
LEFT JOIN (
    -- credits of courses in each term where the student failed attendance eligibility
    SELECT spe.ukid, ee.term_id,
           SUM(COALESCE(tc.course_credits, co.course_credits, 0)) AS absence_credits
    FROM ems_student_programme_enrollment spe
    JOIN student_profile sp4             ON sp4.ukid = spe.ukid AND sp4.student_status_id IS NOT NULL
    JOIN ems_examination ee              ON ee.id = spe.exam_id
    JOIN ems_student_course_enrollment sce ON sce.student_programme_enrollment_id = spe.id
                                          AND sce.enrollment_status IN ('ENROLLED', 'AUTO_ENROLLED')
                                          AND sce.attendance_eligibility = 0
    JOIN term_course tc                  ON tc.id = sce.term_course_id
    LEFT JOIN course co                  ON co.course_id = tc.course_id
    GROUP BY spe.ukid, ee.term_id
) cr ON cr.ukid = sp.ukid AND cr.term_id = lt.term_id
WHERE NOT EXISTS (SELECT 1 FROM alumni_profile ap WHERE ap.ukid = sp.ukid)   -- graduates are reported in the Graduates report
ORDER BY `Last Academic Period` DESC, `Student ID`;
