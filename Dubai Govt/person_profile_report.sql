-- Person Profile report (CHEDS/KHDA PERSON_PROFILE sheet).
-- One row per active student, faculty or administrator (employee) user (active login in authenticator).
-- Sources: user_attributes + student_profile / faculty_profile / admin_profile + authenticator (email, phone, active flag)
--   + Student Management / ePortfolio custom fields (user_details_master_field_value, list fields resolved to the item name).
-- Fields marked "Custom Field" in the spec do not exist yet; they are read from the custom field identifiers named in the
--   column comments (EMIRATES_ID, GCC_ID, ...) and stay NULL until those fields are created with these identifiers.
-- Dates are reported as DD-MM-YYYY (spec: Day Month Year, size 10).
-- Columns marked "To Be Checked" need the value mapped to the spec's code list.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    COALESCE(NULLIF(TRIM(sp.registration_id), ''),
             NULLIF(TRIM(ua.registration_id), ''), ua.ukid)             AS `Person Id`,
    CASE ua.user_type
         WHEN 'student' THEN 'Student'
         WHEN 'faculty' THEN 'Faculty'
         ELSE 'Employee' END                                            AS `Person Type Flag`,
    NULLIF(REPLACE(REPLACE(cf.emirates_id, '-', ''), ' ', ''), '')      AS `Emirates Id`,                   -- Custom field EMIRATES_ID (15 digits, dashes / spaces removed)
    cf.gcc_id                                                           AS `GCC ID`,                        -- Custom field GCC_ID (GCC nationals without an Emirates ID)
    COALESCE(cf.passport_number, NULLIF(TRIM(sp.passport_number), ''))  AS `Passport Number`,               -- Custom field PASSPORT_NUMBER, falls back to the student profile
    CASE WHEN cf.emirates_id IS NULL THEN cf.eid_missing_reason END     AS `Reason Emirates Id is Missing`, -- Custom field EMIRATES_ID_MISSING_REASON (only when Emirates ID is blank)
    cf.napo_id                                                          AS `Napo Id`,                       -- Custom field NAPO_ID (federal HEIs only)
    TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''),
                        NULLIF(TRIM(ua.m_name), ''),
                        NULLIF(TRIM(ua.l_name), '')))                   AS `Person Name English`,
    cf.name_arabic                                                      AS `Person Name Arabic`,            -- Custom field NAME_ARABIC
    CASE LOWER(COALESCE(sp.gender, fp.gender, ap.gender))
         WHEN 'male'   THEN 'Male'
         WHEN 'female' THEN 'Female' END                                AS `Gender`,                        -- Accepted values Male / Female only
    DATE_FORMAT(COALESCE(sp.date_of_birth, fp.date_of_birth, ap.date_of_birth,
                         STR_TO_DATE(cf.date_of_birth, '%Y-%m-%d')), '%d-%m-%Y') AS `Date Of Birth`,
    cf.national_service_status                                          AS `National Service Status`,       -- Custom field NATIONAL_SERVICE_STATUS (Completed / Exempted / Deferred / In Progress / Not Eligible)
    DATE_FORMAT(STR_TO_DATE(cf.national_service_date, '%Y-%m-%d'),
                '%d-%m-%Y')                                             AS `National Service Status Date`,  -- Custom field NATIONAL_SERVICE_STATUS_DATE
    a.email                                                             AS `Email Address`,
    COALESCE(NULLIF(TRIM(ua.secondary_email), ''), cf.personal_email)   AS `Personal Email Address`,        -- Secondary email, falls back to custom field ALTERNATE_EMAIL_ID
    COALESCE(NULLIF(TRIM(a.phone), ''),
             NULLIF(TRIM(COALESCE(sp.phone, fp.phone, ap.phone)), ''),
             cf.phone_number)                                           AS `Phone Number`,
    COALESCE(NULLIF(TRIM(sp.nationality), ''), cf.nationality,
             NULLIF(TRIM(sp.citizenship), ''), cf.citizenship)          AS `Nationality`,                   -- To Be Checked: map to ISO 3166 Alpha-2 / Alpha-3 code
    cf.mother_nationality                                               AS `Nationality of Mother`,         -- Custom field MOTHER_NATIONALITY; To Be Checked: map to ISO 3166 code
    cf.emirate                                                          AS `Emirate as per Passport/Residency`, -- Custom field EMIRATE_AS_PER_PASSPORT_RESIDENCY
    CASE WHEN cf.physically_disabled = 'YES'
           OR cf.pod_category IS NOT NULL
           OR cf.disability_type IS NOT NULL
         THEN 'Y' ELSE 'N' END                                          AS `POD Indicator`,
    COALESCE(cf.pod_category, cf.disability_type)                       AS `POD Category`,                  -- Custom field POD_CATEGORY, falls back to Type of Disability
    cf.orcid                                                            AS `ORCID`                          -- Custom field ORCID (researchers / faculty)
FROM user_attributes ua
JOIN authenticator a              ON a.ukid = ua.ukid AND a.is_active = 1
LEFT JOIN student_profile sp      ON sp.ukid = ua.ukid AND ua.user_type = 'student'
LEFT JOIN faculty_profile fp      ON fp.ukid = ua.ukid AND ua.user_type = 'faculty'
LEFT JOIN admin_profile ap        ON ap.ukid = ua.ukid AND ua.user_type = 'administrator'
LEFT JOIN (
    -- person custom fields; list fields store the list item id
    SELECT
        v.ukid,
        MAX(CASE WHEN f.identifier = 'EMIRATES_ID'                       THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS emirates_id,
        MAX(CASE WHEN f.identifier = 'GCC_ID'                            THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS gcc_id,
        MAX(CASE WHEN f.identifier = 'PASSPORT_NUMBER'                   THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS passport_number,
        MAX(CASE WHEN f.identifier = 'EMIRATES_ID_MISSING_REASON'        THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS eid_missing_reason,
        MAX(CASE WHEN f.identifier = 'NAPO_ID'                           THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS napo_id,
        MAX(CASE WHEN f.identifier = 'NAME_ARABIC'                       THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS name_arabic,
        MAX(CASE WHEN f.identifier = 'DATE_OF_BIRTH'                     THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS date_of_birth,
        MAX(CASE WHEN f.identifier = 'NATIONAL_SERVICE_STATUS'           THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS national_service_status,
        MAX(CASE WHEN f.identifier = 'NATIONAL_SERVICE_STATUS_DATE'      THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS national_service_date,
        MAX(CASE WHEN f.identifier = 'ALTERNATE_EMAIL_ID'                THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS personal_email,
        MAX(CASE WHEN f.identifier = 'PHONE_NUMBER'                      THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS phone_number,
        MAX(CASE WHEN f.identifier = 'NATIONALITY'                       THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS nationality,
        MAX(CASE WHEN f.identifier = 'CITIZENSHIP'                       THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS citizenship,
        MAX(CASE WHEN f.identifier = 'MOTHER_NATIONALITY'                THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS mother_nationality,
        MAX(CASE WHEN f.identifier = 'EMIRATE_AS_PER_PASSPORT_RESIDENCY' THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS emirate,
        MAX(CASE WHEN f.identifier = 'IS_PHYSICALLY_DISABLED'            THEN UPPER(NULLIF(TRIM(COALESCE(li.name, v.value)), '')) END) AS physically_disabled,
        MAX(CASE WHEN f.identifier IN ('TYPE_OF_DISABILITY', 'PHYSICALLY_DISABLED_TYPE')
                  AND UPPER(TRIM(COALESCE(li.name, v.value))) NOT IN ('', 'NA', 'N/A', 'NO', 'NONE') THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END)  AS disability_type,
        MAX(CASE WHEN f.identifier = 'POD_CATEGORY'
                  AND UPPER(TRIM(COALESCE(li.name, v.value))) NOT IN ('', 'NA', 'N/A', 'NO', 'NONE') THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END)  AS pod_category,
        MAX(CASE WHEN f.identifier = 'ORCID'                             THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS orcid
    FROM user_details_master_field_value v
    JOIN user_details_master_field f                ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id AND li.id = v.value
    WHERE f.identifier IN ('EMIRATES_ID', 'GCC_ID', 'PASSPORT_NUMBER', 'EMIRATES_ID_MISSING_REASON', 'NAPO_ID', 'NAME_ARABIC',
                           'DATE_OF_BIRTH', 'NATIONAL_SERVICE_STATUS', 'NATIONAL_SERVICE_STATUS_DATE', 'ALTERNATE_EMAIL_ID',
                           'PHONE_NUMBER', 'NATIONALITY', 'CITIZENSHIP', 'MOTHER_NATIONALITY',
                           'EMIRATE_AS_PER_PASSPORT_RESIDENCY', 'IS_PHYSICALLY_DISABLED', 'TYPE_OF_DISABILITY',
                           'PHYSICALLY_DISABLED_TYPE', 'POD_CATEGORY', 'ORCID')
    GROUP BY v.ukid
) cf ON cf.ukid = ua.ukid
WHERE ua.user_type IN ('student', 'faculty', 'administrator')
ORDER BY `Person Type Flag`, `Person Id`;
