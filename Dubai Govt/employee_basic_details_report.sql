-- Employee - Basic Details report (CHEDS/KHDA format).
-- One row per active faculty / administrator (staff) user.
-- Sources: user_attributes + faculty_profile / admin_profile + authenticator (email, phone, active flag) + ePortfolio
--   (user_details_master_*: PERSONAL_DETAILS, CONTACT_DETAILS, CURRENT_EMPLOYMENT, EXPERIENCE, QUALIFICATION_DETAILS).
-- Qualification columns come from the most recently completed QUALIFICATION_DETAILS entry (highest qualification).
-- Campus = campus-layer (layer 5) ancestor of the department's institution entity; College = department's parent entity
--   (academic departments only, 'NA' for non-academic staff as per spec).
-- Academic period is the reporting period as of today, coded <acad_year_start><semester>0 with the academic year
--   starting in September: Sep-Dec -> 10 (Fall), Jan-May -> 20 (Spring), Jun-Aug -> 30 (Summer), e.g. Oct 2026 -> 202610.
--   To be mapped (CHEDS Semester Code list)
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet; spec defaults are used where the spec gives one.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,          -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    (YEAR(CURDATE()) - (MONTH(CURDATE()) < 9)) * 100
      + CASE WHEN MONTH(CURDATE()) >= 9 THEN 10
             WHEN MONTH(CURDATE()) <= 5 THEN 20
             ELSE 30 END                                                AS `Academic Period`,
    ua.registration_id                                                  AS `Employee ID`,
    999999999999999                                                     AS `Emirates ID`,               -- Enhancement Required (spec default when EID not available)
    NULL                                                                AS `Reason for missing EID`,    -- Enhancement Required (Reason for Missing EID list)
    CASE LOWER(COALESCE(fp.gender, ap.gender))
         WHEN 'male'   THEN 'M'
         WHEN 'female' THEN 'F' END                                     AS `Gender`,
    NULL                                                                AS `Payroll`,                   -- Enhancement Required (Payroll list)
    COALESCE(NULLIF(TRIM(pd.citizenship), ''), NULLIF(TRIM(pd.nationality), '')) AS `Nationality`,  -- Country code to be mapped (CHEDS Country list, e.g. AE)
    COALESCE(NULLIF(TRIM(pd.date_of_birth), ''),
             DATE_FORMAT(COALESCE(fp.date_of_birth, ap.date_of_birth), '%Y-%m-%d')) AS `Date of Birth`,
    COALESCE(campus.name, 'NA')                                         AS `Campus`,                    -- Campus code to be mapped (CHEDS campus codes)
    a.email                                                             AS `Email`,
    COALESCE(NULLIF(TRIM(a.phone), ''), NULLIF(TRIM(COALESCE(fp.phone, ap.phone)), ''),
             NULLIF(TRIM(pd.phone_number), ''), '+999-99-9999999')      AS `Phone Number`,
    COALESCE(NULLIF(TRIM(pd.certificate_name), ''),
             TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''),
                                 NULLIF(TRIM(ua.m_name), ''),
                                 NULLIF(TRIM(ua.l_name), ''))))         AS `Name`,
    NULLIF(TRIM(pd.date_of_joining), '')                                AS `Hire Date`,
    d.department_name                                                   AS `Department`,
    CASE WHEN d.category = 'academic' THEN COALESCE(de.name, 'NA')
         ELSE 'NA' END                                                  AS `College`,
    NULL                                                                AS `Last Promotion Date`,       -- Enhancement Required (optional)
    COALESCE(NULLIF(TRIM(q.qualification), ''),
             NULLIF(TRIM(pd.highest_qualification), ''))                AS `Qualification`,             -- Degree code to be mapped (CHEDS Degrees list, e.g. DR)
    NULL                                                                AS `Qualification Country`,     -- Enhancement Required (CHEDS Country list)
    COALESCE(NULLIF(TRIM(q.institute_name), ''),
             NULLIF(TRIM(q.university_name), ''), 'NA')                 AS `Qualification Institution Name`,
    '9999'                                                              AS `Qualification Institution Code`, -- Enhancement Required (spec default when code not available)
    COALESCE(LEFT(NULLIF(TRIM(q.completed_on), ''), 4), '0000')         AS `Qualification Year`,
    COALESCE(NULLIF(TRIM(q.degree), ''), 'NA')                          AS `Qualification Name`,
    COALESCE(NULLIF(TRIM(q.specialization), ''), 'NA')                  AS `Qualification Major`,
    NULL                                                                AS `Equivalency Indicator`,     -- Enhancement Required (Y / R / N / A)
    NULL                                                                AS `Equivalency Application Number`, -- Enhancement Required
    COALESCE(NULLIF(TRIM(dg.name), ''),
             NULLIF(TRIM(COALESCE(fp.designation, ap.designation)), ''),
             NULLIF(TRIM(pd.exact_designation), ''))                    AS `Position Title`,            -- Position code to be mapped (CHEDS Position list)
    NULL                                                                AS `Position Title Other`,      -- To Be Checked (only when Position Title = Other)
    COALESCE(NULLIF(TRIM(pd.employment_type), ''),
             NULLIF(TRIM(pd.employment_status), ''))                    AS `Employment Status`,         -- To Be Checked: map to CHEDS Employment Status list (e.g. FT / PT)
    NULLIF(TRIM(pd.total_experience), '')                               AS `Years of experience`,
    NULL                                                                AS `ORCID ID`,                  -- Enhancement Required (mandatory for researchers / faculty)
    DATE_FORMAT(GREATEST(COALESCE(ua.updated_timestamp, '1970-01-01'),
                         COALESCE(fp.modified_timestamp, ap.modified_timestamp, '1970-01-01'),
                         COALESCE(pd.last_updated, '1970-01-01'),
                         COALESCE(q.last_updated, '1970-01-01')), '%Y-%m-%d') AS `Last Updated`
FROM user_attributes ua
JOIN authenticator a                  ON a.ukid = ua.ukid AND a.is_active = 1
LEFT JOIN faculty_profile fp          ON fp.ukid = ua.ukid AND ua.user_type = 'faculty'
LEFT JOIN admin_profile ap            ON ap.ukid = ua.ukid AND ua.user_type = 'administrator'
LEFT JOIN college c                   ON c.college_id = ua.college_id
LEFT JOIN department d                ON d.department_id = COALESCE(fp.department_id, ap.department_id)
LEFT JOIN designation dg              ON dg.id = COALESCE(fp.designation_id, ap.designation_id)
-- department's institution entity hierarchy (school / faculty -> campus)
LEFT JOIN institution_entity de       ON de.id = d.parent_entity_id
LEFT JOIN institution_entity de2      ON de2.id = de.parent_entity_id
LEFT JOIN institution_entity de3      ON de3.id = de2.parent_entity_id
LEFT JOIN institution_entity de4      ON de4.id = de3.parent_entity_id
LEFT JOIN institution_entity campus   ON campus.id = CASE WHEN de.layer_id  = 5 THEN de.id
                                                          WHEN de2.layer_id = 5 THEN de2.id
                                                          WHEN de3.layer_id = 5 THEN de3.id
                                                          WHEN de4.layer_id = 5 THEN de4.id END
LEFT JOIN (
    -- single-entry ePortfolio fields (personal, contact, employment, experience)
    SELECT
        v.ukid,
        MAX(CASE WHEN f.identifier = 'CITIZENSHIP'           THEN v.value END) AS citizenship,
        MAX(CASE WHEN f.identifier = 'NATIONALITY'           THEN v.value END) AS nationality,
        MAX(CASE WHEN f.identifier = 'DATE_OF_BIRTH'         THEN v.value END) AS date_of_birth,
        MAX(CASE WHEN f.identifier = 'CERTIFICATE_NAME'      THEN v.value END) AS certificate_name,
        MAX(CASE WHEN f.identifier = 'HIGHEST_QUALIFICATION' THEN v.value END) AS highest_qualification,
        MAX(CASE WHEN f.identifier = 'PHONE_NUMBER'          THEN v.value END) AS phone_number,
        MAX(CASE WHEN f.identifier = 'DATE_OF_JOINING'       THEN v.value END) AS date_of_joining,
        MAX(CASE WHEN f.identifier = 'EXACT_DESIGNATION'     THEN v.value END) AS exact_designation,
        MAX(CASE WHEN f.identifier = 'EMPLOYMENT_TYPE'       THEN COALESCE(li.name, v.value) END) AS employment_type,
        MAX(CASE WHEN f.identifier = 'EMPLOYMENT_STATUS'     THEN v.value END) AS employment_status,
        MAX(CASE WHEN f.identifier = 'TOTAL_EXPERIENCE'      THEN v.value END) AS total_experience,
        MAX(v.modified_timestamp)                                              AS last_updated
    FROM user_details_master_field_value v
    JOIN user_details_master_field f                ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id
                                                    AND li.id = v.value
    WHERE f.identifier IN ('CITIZENSHIP', 'NATIONALITY', 'DATE_OF_BIRTH', 'CERTIFICATE_NAME', 'HIGHEST_QUALIFICATION',
                           'PHONE_NUMBER', 'DATE_OF_JOINING', 'EXACT_DESIGNATION', 'EMPLOYMENT_TYPE',
                           'EMPLOYMENT_STATUS', 'TOTAL_EXPERIENCE')
      AND NULLIF(TRIM(v.value), '') IS NOT NULL
    GROUP BY v.ukid
) pd ON pd.ukid = ua.ukid
LEFT JOIN (
    -- QUALIFICATION_DETAILS entries pivoted, then the latest completed entry per user
    SELECT qe.*
    FROM (
        SELECT
            v.ukid,
            v.cluster_entry_id,
            MAX(CASE WHEN f.identifier = 'QUALIFICATION'            THEN v.value END) AS qualification,
            MAX(CASE WHEN f.identifier = 'DEGREE'                   THEN v.value END) AS degree,
            MAX(CASE WHEN f.identifier = 'AREA_OF_SPECIALIZATION'   THEN v.value END) AS specialization,
            MAX(CASE WHEN f.identifier = 'INSTITUTE_NAME'           THEN v.value END) AS institute_name,
            MAX(CASE WHEN f.identifier = 'UNIVERSITY_OR_BOARD_NAME' THEN v.value END) AS university_name,
            MAX(CASE WHEN f.identifier = 'COMPLETED_ON'             THEN v.value END) AS completed_on,
            MAX(v.modified_timestamp)                                                 AS last_updated
        FROM user_details_master_cluster_entry_field_value v
        JOIN user_details_master_field f ON f.id = v.field_id
        WHERE f.identifier IN ('QUALIFICATION', 'DEGREE', 'AREA_OF_SPECIALIZATION', 'INSTITUTE_NAME',
                               'UNIVERSITY_OR_BOARD_NAME', 'COMPLETED_ON')
          AND NULLIF(TRIM(v.value), '') IS NOT NULL
        GROUP BY v.ukid, v.cluster_entry_id
    ) qe
    JOIN (
        SELECT v.ukid,
               SUBSTRING_INDEX(GROUP_CONCAT(v.cluster_entry_id
                                            ORDER BY IF(f.identifier = 'COMPLETED_ON', v.value, '') DESC,
                                                     v.cluster_entry_id DESC), ',', 1) AS cluster_entry_id
        FROM user_details_master_cluster_entry_field_value v
        JOIN user_details_master_field f ON f.id = v.field_id
        WHERE f.identifier IN ('QUALIFICATION', 'DEGREE', 'COMPLETED_ON')
          AND NULLIF(TRIM(v.value), '') IS NOT NULL
        GROUP BY v.ukid
    ) latest ON latest.ukid = qe.ukid AND latest.cluster_entry_id = qe.cluster_entry_id
) q ON q.ukid = ua.ukid
WHERE ua.user_type IN ('faculty', 'administrator')
ORDER BY `Institution Name`, `Department`, `Employee ID`;
