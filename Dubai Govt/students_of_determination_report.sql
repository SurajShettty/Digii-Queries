-- Students of Determination (SOD) report (CHEDS/KHDA format).
-- One row per currently enrolled student of determination = student profile with no custom student status, not converted
-- to alumni (same as the Enrollment report) and flagged as a person of determination: "Physically Disabled" = Yes, a
-- disability type entered, special category PH / PWD(PHC), or any SOD custom field indicating assistive devices /
-- special accommodations.
-- Academic Period = latest regular term in which the student has courses (course registration or exam enrolment);
-- falls back to the term running on the report date when the student has no courses yet.
-- SOD details come from Student Management custom fields (user_details_master_field, identifiers SOD_*). Multiple values
-- may be entered comma separated; they are reported semicolon separated as KHDA expects.
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (KHDA Dict)
-- Columns marked "Enhancement Required" / "To Be Checked" have no (reliable) source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,              -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    COALESCE(tr.last_period,
             (SELECT t.acad_year_start * 100 + t.sequence * 10          -- term running on the report date (programme term preferred over all-programme term)
              FROM term t
              WHERE CURDATE() BETWEEN DATE(t.starts) AND DATE(t.ends)
                AND (t.programme_id = sp.programme_id OR (t.all_programmes = 1 AND t.college_id = c.college_id))
              ORDER BY (t.programme_id = sp.programme_id) DESC, IFNULL(t.additional_term, 0), DATEDIFF(t.ends, t.starts), t.starts DESC
              LIMIT 1))                                                 AS `Academic Period`,
    COALESCE(NULLIF(TRIM(sp.registration_id), ''), ua.registration_id)  AS `Student ID`,
    CASE
         WHEN cf.accommodation_type IN ('Y', 'YES', 'ON CAMPUS', 'ON-CAMPUS')   THEN 'Y'
         WHEN cf.accommodation_type IN ('O', 'OFF CAMPUS', 'OFF-CAMPUS')        THEN 'O'
         ELSE 'N'
    END                                                                 AS `Accomodation type`,             -- Custom field SOD_ACCOMMODATION_TYPE (Y on campus / O off campus / N not needed)
    REPLACE(cf.national_award_participated, ',', ';')                   AS `Name of National Award student participated in`, -- Custom field SOD_NATIONAL_AWARD_PARTICIPATED
    REPLACE(cf.national_award_won, ',', ';')                            AS `Name of National Award student WON`,             -- Custom field SOD_NATIONAL_AWARD_WON
    REPLACE(cf.international_award_participated, ',', ';')              AS `Name of INTERNATIONAL Award student participated in`, -- Custom field SOD_INTERNATIONAL_AWARD_PARTICIPATED
    REPLACE(cf.international_award_won, ',', ';')                       AS `Name of INTERNATIONAL Award student WON`,        -- Custom field SOD_INTERNATIONAL_AWARD_WON
    CASE WHEN cf.instructional_tech IN ('Y', 'YES')
           OR (cf.instructional_tech IS NULL AND cf.instructional_tech_details IS NOT NULL)
         THEN 'Y' ELSE 'N' END                                          AS `Instructional assitive technology`,       -- Custom field SOD_INSTRUCTIONAL_ASSISTIVE_TECHNOLOGY
    CASE WHEN cf.instructional_tech IN ('Y', 'YES')
           OR (cf.instructional_tech IS NULL AND cf.instructional_tech_details IS NOT NULL)
         THEN REPLACE(cf.instructional_tech_details, ',', ';') END      AS `Instructional assitive technology details`, -- Custom field SOD_INSTRUCTIONAL_ASSISTIVE_TECHNOLOGY_DETAILS (mandatory when above = 'Y')
    CASE WHEN cf.medical_devices IN ('Y', 'YES')
           OR (cf.medical_devices IS NULL AND cf.medical_devices_details IS NOT NULL)
         THEN 'Y' ELSE 'N' END                                          AS `Medical assitive devices`,                -- Custom field SOD_MEDICAL_ASSISTIVE_DEVICES
    CASE WHEN cf.medical_devices IN ('Y', 'YES')
           OR (cf.medical_devices IS NULL AND cf.medical_devices_details IS NOT NULL)
         THEN REPLACE(cf.medical_devices_details, ',', ';') END         AS `Medical assitive devices details`,        -- Custom field SOD_MEDICAL_ASSISTIVE_DEVICES_DETAILS (mandatory when above = 'Y')
    COALESCE(REPLACE(cf.special_accommodation, ',', ';'), 'NO')         AS `Special Accomodations`,                   -- Custom field SOD_SPECIAL_ACCOMMODATION; Special Accommodations code to be mapped (KHDA Dict, NO when none)
    CASE WHEN COALESCE(cf.special_accommodation, 'NO') <> 'NO'
         THEN COALESCE(cf.special_accommodation_details,
                       cf.disability_type) END                          AS `Special Accomodations details`,           -- Custom field SOD_SPECIAL_ACCOMMODATION_DETAILS; To Be Checked: falls back to the disability type
    DATE_FORMAT(GREATEST(COALESCE(cf.last_updated, sp.modified_timestamp, ua.updated_timestamp),
                         COALESCE(sp.modified_timestamp, ua.updated_timestamp, cf.last_updated)),
                '%Y-%m-%d')                                             AS `Last Updated`
FROM student_profile sp
JOIN user_attributes ua          ON ua.ukid = sp.ukid
LEFT JOIN college c              ON c.college_id = COALESCE(sp.college_id, ua.college_id)
JOIN (
    -- student profile custom fields; list fields store the list item id
    SELECT v.ukid,
           MAX(CASE WHEN f.identifier = 'IS_PHYSICALLY_DISABLED'                     THEN li.name END)                  AS physically_disabled,
           MAX(CASE WHEN f.identifier IN ('TYPE_OF_DISABILITY', 'PHYSICALLY_DISABLED_TYPE')
                     AND UPPER(TRIM(v.value)) NOT IN ('', 'NA', 'N/A', 'NO', 'NONE')  THEN TRIM(v.value) END)           AS disability_type,
           MAX(CASE WHEN f.identifier = 'SPECIAL_CATEGORY_LIST'                      THEN li.name END)                  AS special_category,
           MAX(CASE WHEN f.identifier = 'SOD_ACCOMMODATION_TYPE'
                    THEN UPPER(TRIM(COALESCE(li.name, v.value))) END)                                                   AS accommodation_type,
           MAX(CASE WHEN f.identifier = 'SOD_NATIONAL_AWARD_PARTICIPATED'            THEN NULLIF(TRIM(v.value), '') END) AS national_award_participated,
           MAX(CASE WHEN f.identifier = 'SOD_NATIONAL_AWARD_WON'                     THEN NULLIF(TRIM(v.value), '') END) AS national_award_won,
           MAX(CASE WHEN f.identifier = 'SOD_INTERNATIONAL_AWARD_PARTICIPATED'       THEN NULLIF(TRIM(v.value), '') END) AS international_award_participated,
           MAX(CASE WHEN f.identifier = 'SOD_INTERNATIONAL_AWARD_WON'                THEN NULLIF(TRIM(v.value), '') END) AS international_award_won,
           MAX(CASE WHEN f.identifier = 'SOD_INSTRUCTIONAL_ASSISTIVE_TECHNOLOGY'
                    THEN NULLIF(UPPER(TRIM(COALESCE(li.name, v.value))), '') END)                                       AS instructional_tech,
           MAX(CASE WHEN f.identifier = 'SOD_INSTRUCTIONAL_ASSISTIVE_TECHNOLOGY_DETAILS' THEN NULLIF(TRIM(v.value), '') END) AS instructional_tech_details,
           MAX(CASE WHEN f.identifier = 'SOD_MEDICAL_ASSISTIVE_DEVICES'
                    THEN NULLIF(UPPER(TRIM(COALESCE(li.name, v.value))), '') END)                                       AS medical_devices,
           MAX(CASE WHEN f.identifier = 'SOD_MEDICAL_ASSISTIVE_DEVICES_DETAILS'      THEN NULLIF(TRIM(v.value), '') END) AS medical_devices_details,
           MAX(CASE WHEN f.identifier = 'SOD_SPECIAL_ACCOMMODATION'
                    THEN NULLIF(UPPER(TRIM(COALESCE(li.name, v.value))), '') END)                                       AS special_accommodation,
           MAX(CASE WHEN f.identifier = 'SOD_SPECIAL_ACCOMMODATION_DETAILS'          THEN NULLIF(TRIM(v.value), '') END) AS special_accommodation_details,
           MAX(CASE WHEN f.identifier LIKE 'SOD\_%' THEN v.modified_timestamp END)                                       AS last_updated
    FROM user_details_master_field_value v
    JOIN student_profile sp2                        ON sp2.ukid = v.ukid AND sp2.student_status_id IS NULL
    JOIN user_details_master_field f                ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id AND li.id = v.value
    WHERE f.identifier IN ('IS_PHYSICALLY_DISABLED', 'TYPE_OF_DISABILITY', 'PHYSICALLY_DISABLED_TYPE', 'SPECIAL_CATEGORY_LIST')
       OR f.identifier LIKE 'SOD\_%'
    GROUP BY v.ukid
) cf ON cf.ukid = sp.ukid
LEFT JOIN (
    -- first / latest regular term the student had courses in (course registration or exam enrolment)
    SELECT sc.ukid,
           CAST(SUBSTRING(MAX(CONCAT(DATE_FORMAT(t.starts, '%Y%m%d'), t.acad_year_start * 100 + t.sequence * 10)), 9) AS UNSIGNED) AS last_period
    FROM (
        SELECT r.ukid, r.term_course_id
        FROM ems_student_course_registration_details r
        UNION
        SELECT spe.ukid, sce.term_course_id
        FROM ems_student_programme_enrollment spe
        JOIN ems_student_course_enrollment sce ON sce.student_programme_enrollment_id = spe.id
                                              AND sce.enrollment_status IN ('ENROLLED', 'AUTO_ENROLLED')
    ) sc
    JOIN term_course tc ON tc.id = sc.term_course_id
    JOIN term t         ON t.id = tc.term_id AND IFNULL(t.additional_term, 0) = 0
    GROUP BY sc.ukid
) tr ON tr.ukid = sp.ukid
WHERE sp.student_status_id IS NULL                                            -- leavers are reported in the Attrition report
  AND NOT EXISTS (SELECT 1 FROM alumni_profile ap WHERE ap.ukid = sp.ukid)    -- graduates are reported in the Graduates report
  AND (cf.physically_disabled = 'Yes'                                         -- students of determination
    OR cf.disability_type IS NOT NULL
    OR cf.special_category IN ('PH', 'PWD(PHC)')
    OR cf.accommodation_type IN ('Y', 'YES', 'ON CAMPUS', 'ON-CAMPUS', 'O', 'OFF CAMPUS', 'OFF-CAMPUS')
    OR cf.instructional_tech IN ('Y', 'YES') OR cf.instructional_tech_details IS NOT NULL
    OR cf.medical_devices IN ('Y', 'YES') OR cf.medical_devices_details IS NOT NULL
    OR COALESCE(cf.special_accommodation, 'NO') <> 'NO')
ORDER BY `Academic Period` DESC, `Student ID`;
