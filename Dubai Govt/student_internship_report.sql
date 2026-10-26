-- Students - Internship report (CHEDS/KHDA format).
-- One row per student internship = placement application on a job whose placement type is an INTERNSHIP type
-- (Summer / Winter Internship, Contract to hire) where the student was Selected / PLACED.
-- Academic Period = term (of the student's programme, else an all-programme term) running on the internship start date;
-- start date = job joining date, falling back to the date the student was selected (application last modified).
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (KHDA Dict)
-- Internship Status: CN = offer rejected by student, PL = not yet started (no / future joining date), ON = started.
-- Completion (CM) is not captured.
-- Columns marked "Enhancement Required" / "To Be Checked" have no (reliable) source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,              -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    (SELECT t.acad_year_start * 100 + t.sequence * 10
     FROM term t
     WHERE DATE(COALESCE(j.joining_date, pa.modified_timestamp, pa.created_timestamp)) BETWEEN DATE(t.starts) AND DATE(t.ends)
       AND (t.programme_id = sp.programme_id OR (t.all_programmes = 1 AND t.college_id = c.college_id))
     ORDER BY (t.programme_id = sp.programme_id) DESC, IFNULL(t.additional_term, 0), DATEDIFF(t.ends, t.starts), t.starts DESC
     LIMIT 1)                                                           AS `Academic Period`,
    COALESCE(NULLIF(TRIM(sp.registration_id), ''), ua.registration_id)  AS `Student ID`,
    '999999999999999'                                                   AS `Emirates ID`,                   -- Enhancement Required (999999999999999 when not available)
    COALESCE(NULLIF(TRIM(sp.passport_number), ''), cf.passport_number,
             'NA')                                                      AS `Passport Number`,
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
    CASE
         WHEN pt.name = 'Undergraduate' THEN
              CASE WHEN sp.year <= 1 THEN 'FR'
                   WHEN sp.year = 2  THEN 'SO'
                   WHEN sp.year = 3  THEN 'JR'
                   WHEN sp.year >= 4 THEN 'SR'
              END
         ELSE pt.name
    END                                                                 AS `Student Level`,                 -- To Be Checked: UG from current year of study; others to be mapped (KHDA Dict)
    NULL                                                                AS `Area of Specialization (CIP Family code)`, -- Enhancement Required ('99' for unclassified programmes)
    p.programme_code                                                    AS `Program (Program Code)`,        -- Program code to be mapped (KHDA Dict)
    TRIM(po.name)                                                       AS `Internship Organization`,
    COALESCE(ps.name, s.name, po.type)                                  AS `Internship Sector`,             -- To Be Checked: industry stands in for sector (Public/Private/... not captured); Sector code to be mapped
    COALESCE(ps.name, s.name)                                           AS `Internship Industry`,           -- Industry code to be mapped (KHDA Dict)
    NULL                                                                AS `Internship Duration`,           -- Enhancement Required (weeks; only free-text "Internship Period" job info exists)
    NULL                                                                AS `Internship time per week`,      -- Enhancement Required (30-40 hours for full time)
    NULL                                                                AS `Internship type`,               -- Enhancement Required (CHEDS internship type code)
    CASE WHEN COALESCE(j.ctc, j.maximum_ctc_range, j.minimum_ctc_range, 0) > 0
         THEN 'P' ELSE 'NP' END                                         AS `Paid/Unpaid`,
    COALESCE(jl.locations, NULLIF(TRIM(j.location), ''),
             NULLIF(TRIM(po.head_office_location), ''))                 AS `National/Out/Country/Online`,   -- To Be Checked: location name; to be mapped to country code / 'ON' for online
    NULL                                                                AS `Internship Credits`,            -- Enhancement Required (FC / NC / VL)
    NULL                                                                AS `Employer satisfaction`,         -- Enhancement Required (0-5 from employer survey)
    NULL                                                                AS `Course Code`,                   -- Enhancement Required (course linked to the internship)
    DATE_FORMAT(j.joining_date, '%Y-%m-%d')                             AS `Start Date`,
    NULL                                                                AS `End Date`,                      -- Enhancement Required
    NULLIF(TRIM(pc.contact_person), '')                                 AS `Supervisor Name (Organization)`, -- To Be Checked: first organisation contact person
    NULLIF(TRIM(pc.email_id), '')                                       AS `Supervisor Email (Organization)`,
    COALESCE(NULLIF(TRIM(pc.contact_number), ''),
             NULLIF(TRIM(pc.landline_number), ''))                      AS `Supervisor Contact (Organization)`,
    NULL                                                                AS `Supervisor Name (Institution)`, -- Enhancement Required (academic supervisor not captured)
    NULL                                                                AS `Supervisor Email (Institution)`, -- Enhancement Required
    NULL                                                                AS `Supervisor Contact (Institution)`, -- Enhancement Required
    CASE
         WHEN os.name IN ('Reject', 'System Rejected')                 THEN 'CN'
         WHEN j.joining_date IS NULL OR DATE(j.joining_date) > CURDATE() THEN 'PL'
         ELSE 'ON'
    END                                                                 AS `Status`,                        -- To Be Checked: completion (CM) not captured
    'OR'                                                                AS `Payment`,                       -- To Be Checked: organisation-paid assumed (OR = by organization, ST = by student)
    NULL                                                                AS `Organization Trade License`,    -- Enhancement Required
    NULLIF(TRIM(po.head_office_address), '')                            AS `Organization Address`,
    NULL                                                                AS `Organization Emirate`,          -- Enhancement Required
    DATE_FORMAT(GREATEST(pa.modified_timestamp, j.modified_timestamp), '%Y-%m-%d') AS `Last Updated`
FROM placement_application pa
JOIN placement_job j                        ON j.id = pa.job_id AND IFNULL(j.is_deleted, 0) = 0
JOIN placement_types ptp                    ON ptp.id = j.placement_type_id AND ptp.type = 'INTERNSHIP'
JOIN placement_application_status ast       ON ast.id = pa.status_id AND ast.name IN ('Selected', 'PLACED')
LEFT JOIN placement_offer_status os         ON os.id = pa.offer_status_id
JOIN student_profile sp                     ON sp.ukid = pa.ukid
JOIN user_attributes ua                     ON ua.ukid = sp.ukid
LEFT JOIN college c                         ON c.college_id = COALESCE(sp.college_id, ua.college_id, j.college_id)
LEFT JOIN programme p                       ON p.programme_id = sp.programme_id
LEFT JOIN programme_types pt                ON pt.id = p.programme_type_id
LEFT JOIN placement_organization po         ON po.id = j.organization_id
LEFT JOIN placement_organization_sector s   ON s.id = po.sector_id
LEFT JOIN placement_organization_sector ps  ON ps.id = s.parent_id
LEFT JOIN (
    -- first (lowest id) active contact person of the organisation
    SELECT organization_id, MIN(id) AS contact_id
    FROM placement_organization_contact
    WHERE IFNULL(deleted, 0) = 0
    GROUP BY organization_id
) pcm ON pcm.organization_id = po.id
LEFT JOIN placement_organization_contact pc ON pc.id = pcm.contact_id
LEFT JOIN (
    SELECT placement_job_id, GROUP_CONCAT(DISTINCT TRIM(name) ORDER BY name SEPARATOR ', ') AS locations
    FROM placement_job_location
    GROUP BY placement_job_id
) jl ON jl.placement_job_id = j.id
LEFT JOIN (
    -- student profile custom fields
    SELECT v.ukid,
           MAX(CASE WHEN f.identifier = 'NATIONALITY'     THEN NULLIF(TRIM(v.value), '') END) AS nationality,
           MAX(CASE WHEN f.identifier = 'PASSPORT_NUMBER' THEN NULLIF(TRIM(v.value), '') END) AS passport_number
    FROM user_details_master_field_value v
    JOIN user_details_master_field f ON f.id = v.field_id
    WHERE f.identifier IN ('NATIONALITY', 'PASSPORT_NUMBER')
      AND v.ukid IN (SELECT ukid FROM placement_application)
    GROUP BY v.ukid
) cf ON cf.ukid = sp.ukid
WHERE IFNULL(pa.is_deleted, 0) = 0
ORDER BY `Academic Period` DESC, `Student ID`, `Internship Organization`;
