-- Graduates report (CHEDS/KHDA format).
-- One row per graduate = student converted to alumni (Student -> Alumni Conversion, alumni_profile).
-- Personal details come from student_profile, falling back to the student profile custom fields
-- (user_details_master_field_value) for nationality / passport / marital status / disability / mode of study.
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (KHDA Dict)
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet and are returned as NULL.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,              -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    tr.last_period                                                      AS `Graduation Academic Period`,    -- last term the graduate was enrolled in
    COALESCE(ap.registration_id, ua.registration_id)                    AS `Student ID`,
    NULL                                                                AS `Al Khulasa`,                    -- Enhancement Required (UAE nationals only, else 'NA')
    NULL                                                                AS `Emirates ID`,                   -- Enhancement Required (use 000000000000000 if not available)
    NULL                                                                AS `Reason for Missing EID`,        -- Enhancement Required
    COALESCE(NULLIF(TRIM(sp.passport_number), ''), cf.passport_number)  AS `Passport Number`,
    TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''),
                        NULLIF(TRIM(ua.m_name), ''),
                        NULLIF(TRIM(ua.l_name), '')))                   AS `Graduate Name (English)`,
    NULL                                                                AS `Graduate Name (Arabic)`,        -- Enhancement Required
    CASE LOWER(COALESCE(ap.gender, sp.gender))
         WHEN 'male'   THEN 'M'
         WHEN 'female' THEN 'F'
         ELSE 'U'
    END                                                                 AS `Gender`,
    DATE_FORMAT(sp.date_of_birth, '%Y-%m-%d')                           AS `Graduate DOB`,
    COALESCE(NULLIF(TRIM(ua.secondary_email), ''),                      -- personal email preferred over institution login email
             NULLIF(TRIM(a.email), ''),
             'xxx@xxx.com')                                             AS `Graduate Email Address`,
    COALESCE(NULLIF(TRIM(a.phone), ''),
             NULLIF(TRIM(sp.phone), ''),
             NULLIF(TRIM(ua.secondary_phone), ''),
             '+999-99-9999999')                                         AS `Graduate Mobile Number`,
    CASE cf.physically_disabled
         WHEN 'Yes' THEN 'Y'
         WHEN 'No'  THEN 'N'
    END                                                                 AS `People of Determination`,       -- To Be Checked (only "physically disabled" is captured)
    COALESCE(NULLIF(TRIM(sp.marital_status), ''), cf.marital_status)    AS `Marital Status Code`,           -- Marital status code to be mapped (KHDA Dict)
    COALESCE(NULLIF(TRIM(sp.nationality), ''), cf.nationality,
             NULLIF(TRIM(sp.citizenship), ''))                          AS `Nationality`,                   -- Nationality code to be mapped (KHDA Dict)
    NULL                                                                AS `Nationality of Mother`,         -- Enhancement Required
    NULL                                                                AS `Home Emirate (Emirates Code)`,  -- Enhancement Required
    NULL                                                                AS `Graduate Campus`,               -- Enhancement Required (campus code not captured)
    tr.first_period                                                     AS `1st Academic Period`,           -- first term the graduate was enrolled in
    pt.name                                                             AS `Graduate Degree`,               -- Degree code to be mapped (KHDA Dict, e.g. BA)
    NULL                                                                AS `Graduate Area of Specialization (CIP Family code)`, -- Enhancement Required
    COALESCE(ss.major_name, s.name, p.programme_name)                   AS `Graduate Major (text)`,
    NULL                                                                AS `Graduate Major (CIP Major Classification)`,          -- Enhancement Required
    ss.minor_name                                                       AS `Graduate Minor (text)`,
    p.programme_code                                                    AS `Graduate Program (Program Code)`, -- Program code to be mapped (KHDA Dict)
    CASE
         WHEN cf.mode_of_study IN ('Full-Time', 'Regular') THEN 'FT'
         WHEN cf.mode_of_study = 'Part-Time'               THEN 'PT'
    END                                                                 AS `Mode of Program Study (FT/PT)`, -- To Be Checked (Online/Distance/Correspondence not mapped)
    NULL                                                                AS `Master Thesis Title`,           -- Enhancement Required ('NA' for non-thesis programmes)
    NULL                                                                AS `PhD Dissertation Title`,        -- Enhancement Required
    da.total_earned_credits                                             AS `Total Credits (Accumulated)`,   -- from the latest degree audit
    ROUND(cg.cgpa, 2)                                                   AS `GPA (Cumulative)`,              -- latest cumulative CGPA; To Be Checked if scale is not 4
    tr.regular_periods                                                  AS `Total Academic Periods (Regular)`,
    tr.supplementary_periods                                            AS `Total Academic Periods (Supplementary)`,
    (SELECT t.acad_year_start * 100 + t.sequence * 10                   -- term running on the report date (programme term preferred over all-programme term)
     FROM term t
     WHERE CURDATE() BETWEEN DATE(t.starts) AND DATE(t.ends)
       AND (t.programme_id = p.programme_id OR (t.all_programmes = 1 AND t.college_id = c.college_id))
     ORDER BY (t.programme_id = p.programme_id) DESC, t.starts DESC
     LIMIT 1)                                                           AS `Submission Term`,
    NULL                                                                AS `Graduates LC`,                  -- Enhancement Required (C/M/B/N)
    NULL                                                                AS `Graduates Workplacement`,       -- Enhancement Required (Y/N)
    DATE_FORMAT(GREATEST(COALESCE(ap.updated_timestamp, ap.created_timestamp),
                         COALESCE(sp.modified_timestamp, sp.updated_timestamp, ap.updated_timestamp, ap.created_timestamp)),
                '%Y-%m-%d')                                             AS `Last Updated`
FROM alumni_profile ap
JOIN user_attributes ua          ON ua.ukid = ap.ukid
LEFT JOIN student_profile sp     ON sp.ukid = ap.ukid
LEFT JOIN authenticator a        ON a.ukid = ap.ukid
LEFT JOIN college c              ON c.college_id = COALESCE(sp.college_id, ua.college_id)
LEFT JOIN programme p            ON p.programme_id = COALESCE(ap.programme_id, sp.programme_id)
LEFT JOIN programme_types pt     ON pt.id = p.programme_type_id
LEFT JOIN specialisation s       ON s.id = COALESCE(ap.specialisation_id, sp.specialisation_id)
LEFT JOIN (
    -- student profile custom fields; list fields store the list item id
    SELECT v.ukid,
           MAX(CASE WHEN f.identifier = 'NATIONALITY'              THEN NULLIF(TRIM(v.value), '') END) AS nationality,
           MAX(CASE WHEN f.identifier = 'PASSPORT_NUMBER'          THEN NULLIF(TRIM(v.value), '') END) AS passport_number,
           MAX(CASE WHEN f.identifier = 'MARITAL_STATUS'           THEN li.name END)                  AS marital_status,
           MAX(CASE WHEN f.identifier = 'IS_PHYSICALLY_DISABLED'   THEN li.name END)                  AS physically_disabled,
           MAX(CASE WHEN f.identifier = 'GRADUATION_MODE_OF_STUDY' THEN li.name END)                  AS mode_of_study
    FROM user_details_master_field_value v
    JOIN alumni_profile ap2                         ON ap2.ukid = v.ukid
    JOIN user_details_master_field f                ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id AND li.id = v.value
    WHERE f.identifier IN ('NATIONALITY', 'PASSPORT_NUMBER', 'MARITAL_STATUS',
                           'IS_PHYSICALLY_DISABLED', 'GRADUATION_MODE_OF_STUDY')
    GROUP BY v.ukid
) cf ON cf.ukid = ap.ukid
LEFT JOIN (
    -- major / minor specialisations opted by the student
    SELECT pss.ukid,
           GROUP_CONCAT(DISTINCT CASE WHEN psm.specialisation_type = 'MAJOR' THEN sx.name END ORDER BY sx.name SEPARATOR ', ') AS major_name,
           GROUP_CONCAT(DISTINCT CASE WHEN psm.specialisation_type = 'MINOR' THEN sx.name END ORDER BY sx.name SEPARATOR ', ') AS minor_name
    FROM programme_specialisation_student pss
    JOIN programme_specialisation_mapping psm ON psm.id = pss.programme_specialisation_mapping_id AND IFNULL(psm.is_deleted, 0) = 0
    JOIN specialisation sx                    ON sx.id = psm.specialisation_id
    GROUP BY pss.ukid
) ss ON ss.ukid = ap.ukid
LEFT JOIN (
    -- terms in which the student was actually enrolled in courses (exam programme enrolment with enrolled courses)
    SELECT et.ukid,
           CAST(SUBSTRING(MIN(CONCAT(DATE_FORMAT(et.starts, '%Y%m%d'), et.period_code)), 9) AS UNSIGNED) AS first_period,
           CAST(SUBSTRING(MAX(CONCAT(DATE_FORMAT(et.starts, '%Y%m%d'), et.period_code)), 9) AS UNSIGNED) AS last_period,
           COUNT(DISTINCT CASE WHEN IFNULL(et.additional_term, 0) = 0 THEN et.term_id END)          AS regular_periods,
           COUNT(DISTINCT CASE WHEN et.additional_term = 1            THEN et.term_id END)          AS supplementary_periods
    FROM (
        SELECT DISTINCT spe.ukid, t.id AS term_id, t.starts, t.additional_term,
               t.acad_year_start * 100 + t.sequence * 10 AS period_code
        FROM ems_student_programme_enrollment spe
        JOIN alumni_profile ap3 ON ap3.ukid = spe.ukid
        JOIN ems_examination ee ON ee.id = spe.exam_id
        JOIN term t             ON t.id = ee.term_id
        WHERE EXISTS (SELECT 1
                      FROM ems_student_course_enrollment sce
                      WHERE sce.student_programme_enrollment_id = spe.id
                        AND sce.enrollment_status IN ('ENROLLED', 'AUTO_ENROLLED'))
    ) et
    GROUP BY et.ukid
) tr ON tr.ukid = ap.ukid
LEFT JOIN (
    -- latest cumulative CGPA (latest term, then latest generated row)
    SELECT g.student_ukid,
           CAST(SUBSTRING(MAX(CONCAT(DATE_FORMAT(t.starts, '%Y%m%d'), LPAD(g.id, 12, '0'),
                                     COALESCE(g.degree_moderated_cgpa, g.re_exam_cgpa, g.cgpa))), 21) AS DECIMAL(10, 4)) AS cgpa
    FROM ems_examination_student_cgpa g
    JOIN alumni_profile ap4 ON ap4.ukid = g.student_ukid
    JOIN ems_examination e  ON e.id = g.exam_id
    JOIN term t             ON t.id = e.term_id
    WHERE COALESCE(g.degree_moderated_cgpa, g.re_exam_cgpa, g.cgpa) IS NOT NULL
    GROUP BY g.student_ukid
) cg ON cg.student_ukid = ap.ukid
LEFT JOIN (
    -- latest degree audit of the student
    SELECT das.student_ukid, das.total_earned_credits
    FROM ems_degree_audit_student das
    JOIN (SELECT student_ukid, MAX(id) AS max_id
          FROM ems_degree_audit_student
          GROUP BY student_ukid) l ON l.max_id = das.id
) da ON da.student_ukid = ap.ukid
ORDER BY `Graduation Academic Period` DESC, `Student ID`;
