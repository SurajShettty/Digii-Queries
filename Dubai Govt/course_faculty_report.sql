-- Course Faculty report (CHEDS/KHDA format).
-- One row per course section (class) + programme + teaching faculty (class_faculty, substitutes excluded).
-- A class mapped to several programmes is listed once per programme. Programme comes from the class's programme batch
-- sections, else from the programmes of the students added to the class (custom classes), else from the class's term.
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (CHEDS Semester Code list)
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT DISTINCT
    c.university_code                                                   AS `Institution Code`,          -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    p.programme_code                                                    AS `Program Code`,              -- Program code to be mapped (KHDA Dict)
    p.programme_name                                                    AS `Program Name`,
    t.acad_year_start * 100 + t.sequence * 10                           AS `Academic Period`,
    COALESCE(NULLIF(TRIM(tc.course_name), ''), NULLIF(TRIM(tcv.course_name), ''),
             NULLIF(TRIM(dcv.course_name), ''), co.course_name)         AS `Course Name`,   -- term snapshot, else term / default course version
    COALESCE(NULLIF(TRIM(tc.course_code), ''), NULLIF(TRIM(tcv.course_code), ''),
             NULLIF(TRIM(dcv.course_code), ''), co.course_code)         AS `Course Code`,
    COALESCE(NULLIF(TRIM(cl.reference_id), ''), CAST(cl.id AS CHAR))    AS `Course Ref Number`,         -- section reference id, else class id
    CASE WHEN ua.user_type IN ('faculty', 'administrator') THEN 'H' END AS `Faculty type`,              -- To Be Checked (all class faculty are institution users -> H; I/E not captured)
    ua.registration_id                                                  AS `Faculty/Staff ID`,
    TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''),
                        NULLIF(TRIM(ua.m_name), ''),
                        NULLIF(TRIM(ua.l_name), '')))                   AS `Faculty name`,
    NULL                                                                AS `Name of the industry`,      -- Enhancement Required (mandatory when Faculty type = I)
    NULL                                                                AS `Email of the industrial faculty`, -- Enhancement Required (mandatory when Faculty type = I)
    NULL                                                                AS `Percentage of teaching workload`, -- Enhancement Required (0-100)
    NULL                                                                AS `Percentage of course design workload`, -- Enhancement Required (0-100)
    DATE_FORMAT(GREATEST(cf.modified_timestamp, cl.modified_timestamp), '%Y-%m-%d') AS `Last Updated`
FROM class_faculty cf
JOIN class cl                                ON cl.id = cf.class_id
JOIN term t                                  ON t.id = cl.term_id
JOIN user_attributes ua                      ON ua.ukid = cf.faculty_id
LEFT JOIN course co                          ON co.course_id = cl.course_id
LEFT JOIN term_course tc                     ON tc.term_id = cl.term_id AND tc.course_id = cl.course_id
LEFT JOIN course_version tcv                 ON tcv.id = tc.course_version_id
LEFT JOIN course_version dcv                 ON dcv.course_id = cl.course_id AND dcv.is_default = 1
LEFT JOIN (
    -- programmes of a class: mapped programme batch sections, else programmes of the students added to the class
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
) cps ON cps.class_id = cl.id
LEFT JOIN programme p                        ON p.programme_id = COALESCE(cps.programme_id, cl.programme_id, t.programme_id)
LEFT JOIN college c                          ON c.college_id = COALESCE(p.college_id, t.college_id)
WHERE IFNULL(cf.is_substitute, 0) = 0
ORDER BY `Academic Period` DESC, `Program Code`, `Course Code`, `Course Ref Number`, `Faculty/Staff ID`;
