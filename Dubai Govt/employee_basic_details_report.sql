-- Employee - Basic Details report (CHEDS/KHDA format).
-- One row per active faculty / administrator (staff) user.
-- Sources: user_attributes + faculty_profile / admin_profile + authenticator (email, phone, active flag) + ePortfolio
--   (user_details_master_*: PERSONAL_DETAILS, CONTACT_DETAILS, CURRENT_EMPLOYMENT, EXPERIENCE, QUALIFICATION_DETAILS).
-- Qualification columns come from the most recently completed QUALIFICATION_DETAILS entry (highest qualification).
-- Campus = campus-layer (layer 5) ancestor of the department's institution entity; College = department's parent entity
--   (academic departments only, 'NA' for non-academic staff as per spec).
-- Academic Period = <acad_year_start><term sequence>0 of the terms of the staff member's college, e.g. 2025-26 term 1 -> 202510
--   (employee details are a snapshot of currently active staff; staff of colleges with no term in the period are not listed).
--   To be mapped (CHEDS Semester Code list)
-- KHDA codes come from khda_sync (the inner query r returns the Digii values, the outer query maps them):
--   digii_code_map  = confirmed Digii value -> KHDA code per KHDA tenant (khda_code; suggested_code is ignored until confirmed);
--                     kind = the master_value list name below, digii_id = the Digii value
--   institution     = KHDA tenant -> Digii college (digii_data_college_id, else digii_college_id)
--   master_value    = KHDA code lists; mapped codes must exist here
--   Each coded column = confirmed mapping, else a direct label / code match in master_value, else the default:
--     Nationality        list 'country'               default 'NS' (Not Specified) if blank, 'UN' (Unknown) if unmapped
--     Campus             list 'campus'                default NULL (the KHDA list has no catch-all code)
--     Qualification      list 'degreeorprogramlevel'  default 'UD' (Undeclared)
--     Position Title     list 'staffposition'         default 'OTH' (Others); Position Title Other = the Digii title then
--     Employment Status  list 'employmentstatus'      default 'OT' (Other)
-- Filter: {{academic_period}} = Academic Period code, e.g. 202510 (applied to the term-derived period).
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet; spec defaults are used where the spec gives one.
-- MySQL 5.x compatible: no CTEs / window functions. khda_sync uses a different collation, hence the explicit COLLATE.
SELECT
    r.`Institution Code`,
    r.`Institution Name`,
    r.`Academic Period`,
    r.`Employee ID`,
    r.`Emirates ID`,
    r.`Reason for missing EID`,
    r.`Gender`,
    r.`Payroll`,
    CASE WHEN r.raw_nationality IS NULL THEN 'NS' ELSE
    COALESCE(
        (SELECT mv.code
         FROM khda_sync.digii_code_map m
         JOIN khda_sync.institution i   ON i.tenant_id = m.tenant_id
         JOIN khda_sync.master_value mv ON mv.list_name = 'country' AND mv.code = m.khda_code COLLATE utf8mb4_unicode_ci
         WHERE COALESCE(i.digii_data_college_id, i.digii_college_id) = r.college_id
           AND m.kind = 'country' AND m.digii_id COLLATE utf8mb4_unicode_ci = r.raw_nationality
         LIMIT 1),
        (SELECT mv.code FROM khda_sync.master_value mv
         WHERE mv.list_name = 'country' AND r.raw_nationality IN (mv.label, mv.code) LIMIT 1),
        'UN') END                                                       AS `Nationality`,
    r.`Date of Birth`,
    COALESCE(
        (SELECT mv.code
         FROM khda_sync.digii_code_map m
         JOIN khda_sync.institution i   ON i.tenant_id = m.tenant_id
         JOIN khda_sync.master_value mv ON mv.list_name = 'campus' AND mv.code = m.khda_code COLLATE utf8mb4_unicode_ci
         WHERE COALESCE(i.digii_data_college_id, i.digii_college_id) = r.college_id
           AND m.kind = 'campus' AND m.digii_id COLLATE utf8mb4_unicode_ci = r.raw_campus
         LIMIT 1),
        (SELECT mv.code FROM khda_sync.master_value mv
         WHERE mv.list_name = 'campus' AND r.raw_campus IN (mv.label, mv.code) LIMIT 1)) AS `Campus`,
    r.`Email`,
    r.`Phone Number`,
    r.`Name`,
    r.`Hire Date`,
    r.`Department`,
    r.`College`,
    r.`Last Promotion Date`,
    COALESCE(
        (SELECT mv.code
         FROM khda_sync.digii_code_map m
         JOIN khda_sync.institution i   ON i.tenant_id = m.tenant_id
         JOIN khda_sync.master_value mv ON mv.list_name = 'degreeorprogramlevel' AND mv.code = m.khda_code COLLATE utf8mb4_unicode_ci
         WHERE COALESCE(i.digii_data_college_id, i.digii_college_id) = r.college_id
           AND m.kind = 'degreeorprogramlevel' AND m.digii_id COLLATE utf8mb4_unicode_ci = r.raw_qualification
         LIMIT 1),
        (SELECT mv.code FROM khda_sync.master_value mv
         WHERE mv.list_name = 'degreeorprogramlevel' AND r.raw_qualification IN (mv.label, mv.code) LIMIT 1),
        'UD')                                                           AS `Qualification`,
    r.`Qualification Country`,
    r.`Qualification Institution Name`,
    r.`Qualification Institution Code`,
    r.`Qualification Year`,
    r.`Qualification Name`,
    r.`Qualification Major`,
    r.`Equivalency Indicator`,
    r.`Equivalency Application Number`,
    COALESCE(r.position_code, 'OTH')                                    AS `Position Title`,
    CASE WHEN r.position_code IS NULL THEN r.raw_position END           AS `Position Title Other`,      -- only when Position Title = OTH
    COALESCE(
        (SELECT mv.code
         FROM khda_sync.digii_code_map m
         JOIN khda_sync.institution i   ON i.tenant_id = m.tenant_id
         JOIN khda_sync.master_value mv ON mv.list_name = 'employmentstatus' AND mv.code = m.khda_code COLLATE utf8mb4_unicode_ci
         WHERE COALESCE(i.digii_data_college_id, i.digii_college_id) = r.college_id
           AND m.kind = 'employmentstatus' AND m.digii_id COLLATE utf8mb4_unicode_ci = r.raw_employment_status
         LIMIT 1),
        (SELECT mv.code FROM khda_sync.master_value mv
         WHERE mv.list_name = 'employmentstatus' AND r.raw_employment_status IN (mv.label, mv.code) LIMIT 1),
        'OT')                                                           AS `Employment Status`,
    r.`Years of experience`,
    r.`ORCID ID`,
    r.`Last Updated`
FROM (
    SELECT
        p.*,
        COALESCE(
            (SELECT mv.code
             FROM khda_sync.digii_code_map m
             JOIN khda_sync.institution i   ON i.tenant_id = m.tenant_id
             JOIN khda_sync.master_value mv ON mv.list_name = 'staffposition' AND mv.code = m.khda_code COLLATE utf8mb4_unicode_ci
             WHERE COALESCE(i.digii_data_college_id, i.digii_college_id) = p.college_id
               AND m.kind = 'staffposition' AND m.digii_id COLLATE utf8mb4_unicode_ci = p.raw_position
             LIMIT 1),
            (SELECT mv.code FROM khda_sync.master_value mv
             WHERE mv.list_name = 'staffposition' AND p.raw_position IN (mv.label, mv.code) LIMIT 1)) AS position_code
    FROM (
        SELECT
            c.college_id,
            c.university_code                                           AS `Institution Code`,          -- CHEDS institution code to be mapped (KHDA Dict)
            c.college_name                                              AS `Institution Name`,
            per.academic_period                                         AS `Academic Period`,
            ua.registration_id                                          AS `Employee ID`,
            999999999999999                                             AS `Emirates ID`,               -- Enhancement Required (spec default when EID not available)
            NULL                                                        AS `Reason for missing EID`,    -- Enhancement Required (Reason for Missing EID list)
            CASE LOWER(COALESCE(fp.gender, ap.gender))
                 WHEN 'male'   THEN 'M'
                 WHEN 'female' THEN 'F' END                             AS `Gender`,
            NULL                                                        AS `Payroll`,                   -- Enhancement Required (Payroll list)
            CONVERT(COALESCE(NULLIF(TRIM(pd.citizenship), ''),
                             NULLIF(TRIM(pd.nationality), '')) USING utf8mb4) COLLATE utf8mb4_unicode_ci AS raw_nationality,
            COALESCE(NULLIF(TRIM(pd.date_of_birth), ''),
                     DATE_FORMAT(COALESCE(fp.date_of_birth, ap.date_of_birth), '%Y-%m-%d')) AS `Date of Birth`,
            CONVERT(campus.name USING utf8mb4) COLLATE utf8mb4_unicode_ci AS raw_campus,
            a.email                                                     AS `Email`,
            COALESCE(NULLIF(TRIM(a.phone), ''), NULLIF(TRIM(COALESCE(fp.phone, ap.phone)), ''),
                     NULLIF(TRIM(pd.phone_number), ''), '+999-99-9999999') AS `Phone Number`,
            COALESCE(NULLIF(TRIM(pd.certificate_name), ''),
                     TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''),
                                         NULLIF(TRIM(ua.m_name), ''),
                                         NULLIF(TRIM(ua.l_name), '')))) AS `Name`,
            NULLIF(TRIM(pd.date_of_joining), '')                        AS `Hire Date`,
            d.department_name                                           AS `Department`,
            CASE WHEN d.category = 'academic' THEN COALESCE(de.name, 'NA')
                 ELSE 'NA' END                                          AS `College`,
            NULL                                                        AS `Last Promotion Date`,       -- Enhancement Required (optional)
            CONVERT(COALESCE(NULLIF(TRIM(q.qualification), ''),
                             NULLIF(TRIM(pd.highest_qualification), '')) USING utf8mb4) COLLATE utf8mb4_unicode_ci AS raw_qualification,
            NULL                                                        AS `Qualification Country`,     -- Enhancement Required (CHEDS Country list)
            COALESCE(NULLIF(TRIM(q.institute_name), ''),
                     NULLIF(TRIM(q.university_name), ''), 'NA')         AS `Qualification Institution Name`,
            '9999'                                                      AS `Qualification Institution Code`, -- Enhancement Required (spec default when code not available)
            COALESCE(LEFT(NULLIF(TRIM(q.completed_on), ''), 4), '0000') AS `Qualification Year`,
            COALESCE(NULLIF(TRIM(q.degree), ''), 'NA')                  AS `Qualification Name`,
            COALESCE(NULLIF(TRIM(q.specialization), ''), 'NA')          AS `Qualification Major`,
            NULL                                                        AS `Equivalency Indicator`,     -- Enhancement Required (Y / R / N / A)
            NULL                                                        AS `Equivalency Application Number`, -- Enhancement Required
            CONVERT(COALESCE(NULLIF(TRIM(dg.name), ''),
                             NULLIF(TRIM(COALESCE(fp.designation, ap.designation)), ''),
                             NULLIF(TRIM(pd.exact_designation), '')) USING utf8mb4) COLLATE utf8mb4_unicode_ci AS raw_position,
            CONVERT(COALESCE(NULLIF(TRIM(pd.employment_type), ''),
                             NULLIF(TRIM(pd.employment_status), '')) USING utf8mb4) COLLATE utf8mb4_unicode_ci AS raw_employment_status,
            NULLIF(TRIM(pd.total_experience), '')                       AS `Years of experience`,
            NULL                                                        AS `ORCID ID`,                  -- Enhancement Required (mandatory for researchers / faculty)
            DATE_FORMAT(GREATEST(COALESCE(ua.updated_timestamp, '1970-01-01'),
                                 COALESCE(fp.modified_timestamp, ap.modified_timestamp, '1970-01-01'),
                                 COALESCE(pd.last_updated, '1970-01-01'),
                                 COALESCE(q.last_updated, '1970-01-01')), '%Y-%m-%d') AS `Last Updated`
        FROM user_attributes ua
        JOIN authenticator a                  ON a.ukid = ua.ukid AND a.is_active = 1
        LEFT JOIN faculty_profile fp          ON fp.ukid = ua.ukid AND ua.user_type = 'faculty'
        LEFT JOIN admin_profile ap            ON ap.ukid = ua.ukid AND ua.user_type = 'administrator'
        LEFT JOIN college c                   ON c.college_id = ua.college_id
        JOIN (
            -- academic periods of the staff member's college (one row per college + period, terms sharing year + sequence merged)
            SELECT DISTINCT t.college_id, t.acad_year_start * 100 + t.sequence * 10 AS academic_period
            FROM term t
            WHERE t.acad_year_start * 100 + t.sequence * 10 = {{academic_period}}
        ) per                                 ON per.college_id = ua.college_id
        LEFT JOIN department d               ON d.department_id = COALESCE(fp.department_id, ap.department_id)
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
    ) p
) r
ORDER BY r.`Institution Name`, r.`Department`, r.`Employee ID`;
