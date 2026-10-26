-- Students - Research report (CHEDS/KHDA format).
-- One row per research project of a currently enrolled student (ePortfolio cluster STUDENT_PROJECTS);
-- students of PhD programmes without a project entry get one row with the topic taken from their specialisation / programme.
-- Currently enrolled = student profile with no custom student status and not converted to alumni (same as the Enrollment report).
-- Academic Period = latest regular term in which the student has courses (course registration or exam enrolment);
-- falls back to the term running on the report date when the student has no courses yet.
-- Impact indicators are derived from the student ePortfolio clusters (journal / conference publications, patents,
-- participated events, project funding); the rest are not captured and default to 'N'.
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
    TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''),
                        NULLIF(TRIM(ua.m_name), ''),
                        NULLIF(TRIM(ua.l_name), '')))                   AS `Student Name (English)`,
    CASE
         WHEN sp.admission_type = 'TRANSFER' THEN 'TR'
         WHEN tr.first_period IS NULL
           OR tr.first_period = tr.last_period THEN 'NW'
         ELSE 'CN'
    END                                                                 AS `Student Type (Type Code)`,      -- To Be Checked: transfer / new (first period) / continuing; Student Type code to be mapped (KHDA Dict)
    tr.first_period                                                     AS `1st Academic Period`,           -- first regular term the student had courses in
    CASE
         WHEN pt.name = 'Undergraduate' THEN
              CASE WHEN sp.year <= 1 THEN 'FR'
                   WHEN sp.year = 2  THEN 'SO'
                   WHEN sp.year = 3  THEN 'JR'
                   WHEN sp.year >= 4 THEN 'SR'
              END
         ELSE pt.name
    END                                                                 AS `Student Level (Level Code)`,    -- To Be Checked: UG from current year of study; others to be mapped (KHDA Dict)
    pt.name                                                             AS `Student Degree (Degree Code)`,  -- Degree code to be mapped (KHDA Dict, e.g. BA)
    NULL                                                                AS `Area of Specialization (CIP Family code)`, -- Enhancement Required ('99' for undeclared programmes)
    COALESCE(ss.major_name, s.name, p.programme_name)                   AS `Student Major (text)`,
    ss.minor_name                                                       AS `Student Minor`,
    p.programme_code                                                    AS `Student Program (Program Code)`, -- Program code to be mapped (KHDA Dict)
    CASE
         WHEN cf.mode_of_study IN ('Full-Time', 'Regular') OR cf.phd_type = 'Full Time' THEN 'FT'
         WHEN cf.mode_of_study = 'Part-Time'               OR cf.phd_type = 'Part Time' THEN 'PT'
    END                                                                 AS `Mode of Study (FT/PT)`,         -- To Be Checked (Online/Distance/Correspondence not mapped)
    NULL                                                                AS `Type of research`,              -- Enhancement Required (CHEDS Students Research Type code, e.g. RA / TI)
    'FR'                                                                AS `Scholarly Activity Type`,       -- To Be Checked: FRASCATI research assumed (CR = creative endeavours not captured)
    NULL                                                                AS `Name of the international partner organisation`, -- Enhancement Required (mandatory when Type of research = 'TI')
    NULL                                                                AS `Name of the co-supervisor from the international partner organisation`, -- Enhancement Required (mandatory when Type of research = 'TI')
    COALESCE(rp.project_title, s.name, p.programme_name)                AS `Research Topic`,                -- To Be Checked: specialisation / programme stands in as the main research field when no project is entered
    NULL                                                                AS `Research Area`,                 -- Enhancement Required (CHEDS Frascati research area code)
    NULL                                                                AS `ORCID`,                         -- Enhancement Required (blank when not available)
    CASE WHEN im.publications > 0 THEN 'Y' ELSE 'N' END                 AS `Impact indexed publication`,    -- To Be Checked: any journal / conference publication (indexing not captured)
    CASE WHEN im.approved_patents > 0 THEN 'Y' ELSE 'N' END             AS `Impact Registered IP`,          -- approved patent
    CASE WHEN im.event_awards > 0 THEN 'Y' ELSE 'N' END                 AS `Impact Competitions`,           -- To Be Checked: any event won / placed (not limited to research competitions)
    CASE WHEN rp.amount_funded >= 50000 THEN 'Y' ELSE 'N' END           AS `Impact scholarship`,            -- To Be Checked: project funding >= 50,000 (currency not captured)
    'N'                                                                 AS `Impact policy`,                 -- Enhancement Required
    'N'                                                                 AS `Impact Govt`,                   -- Enhancement Required
    'N'                                                                 AS `Impact revenue`,                -- Enhancement Required
    'N'                                                                 AS `Impact Spinoff`,                -- Enhancement Required
    CASE WHEN im.conferences >= 5 THEN 'Y' ELSE 'N' END                 AS `Impact public`,                 -- To Be Checked: 5+ conference presentations (invitations not captured)
    'N'                                                                 AS `Impact education`,              -- Enhancement Required
    'N'                                                                 AS `Impact media`,                  -- Enhancement Required
    DATE_FORMAT(GREATEST(COALESCE(rp.last_updated, im.last_updated, sp.modified_timestamp, ua.updated_timestamp),
                         COALESCE(im.last_updated, rp.last_updated, sp.modified_timestamp, ua.updated_timestamp),
                         COALESCE(sp.modified_timestamp, ua.updated_timestamp, rp.last_updated, im.last_updated)),
                '%Y-%m-%d')                                             AS `Last Updated`
FROM student_profile sp
JOIN user_attributes ua          ON ua.ukid = sp.ukid
LEFT JOIN college c              ON c.college_id = COALESCE(sp.college_id, ua.college_id)
LEFT JOIN programme p            ON p.programme_id = sp.programme_id
LEFT JOIN programme_types pt     ON pt.id = p.programme_type_id
LEFT JOIN specialisation s       ON s.id = sp.specialisation_id
LEFT JOIN (
    -- research projects entered by the student (one record per student per cluster entry)
    SELECT v.ukid,
           v.cluster_entry_id,
           MAX(CASE WHEN f.identifier = 'PROJECT_TITLE' THEN NULLIF(TRIM(v.value), '') END) AS project_title,
           MAX(CASE WHEN f.identifier = 'AMOUNT_FUNDED' AND TRIM(v.value) REGEXP '^[0-9,]+(\\.[0-9]+)?$'
                    THEN CAST(REPLACE(TRIM(v.value), ',', '') AS DECIMAL(15, 2)) END)          AS amount_funded,
           MAX(v.modified_timestamp)                                                            AS last_updated
    FROM user_details_master_cluster_entry_field_value v
    JOIN user_details_master_cluster_entry e ON e.id = v.cluster_entry_id
    JOIN user_details_master_cluster udmc    ON udmc.id = e.cluster_id
    JOIN user_details_master_field f         ON f.id = v.field_id
    WHERE udmc.identifier = 'STUDENT_PROJECTS'
      AND udmc.user_type = 'student'
      AND udmc.active = 1
    GROUP BY v.ukid, v.cluster_entry_id
    HAVING project_title IS NOT NULL
) rp ON rp.ukid = sp.ukid
LEFT JOIN (
    -- research impact evidence per student from the ePortfolio clusters
    SELECT v.ukid,
           COUNT(DISTINCT CASE WHEN udmc.identifier IN ('STUDENT_JOURNAL_PUBLICATION_DETAILS', 'STUDENT_CONFERENCE_PROCEEDING_DETAILS')
                                AND f.identifier = 'TITLE_OF_PAPER' AND NULLIF(TRIM(v.value), '') IS NOT NULL
                               THEN v.cluster_entry_id END)                                  AS publications,
           COUNT(DISTINCT CASE WHEN udmc.identifier = 'STUDENT_CONFERENCE_PROCEEDING_DETAILS'
                                AND f.identifier = 'TITLE_OF_PAPER' AND NULLIF(TRIM(v.value), '') IS NOT NULL
                               THEN v.cluster_entry_id END)                                  AS conferences,
           COUNT(DISTINCT CASE WHEN udmc.identifier = 'STUDENT_PATENT_DETAILS'
                                AND f.identifier = 'PATENT_STATUS' AND li.name = 'Approved'
                               THEN v.cluster_entry_id END)                                  AS approved_patents,
           COUNT(DISTINCT CASE WHEN udmc.identifier = 'PARTICIPATED_EVENTS'
                                AND f.identifier = 'RESULT'
                                AND v.value REGEXP 'win|runner|prize|award|first|second|third|1st|2nd|3rd'
                               THEN v.cluster_entry_id END)                                  AS event_awards,
           MAX(v.modified_timestamp)                                                         AS last_updated
    FROM user_details_master_cluster_entry_field_value v
    JOIN user_details_master_cluster_entry e         ON e.id = v.cluster_entry_id
    JOIN user_details_master_cluster udmc            ON udmc.id = e.cluster_id
    JOIN user_details_master_field f                 ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id AND li.id = v.value
    WHERE udmc.identifier IN ('STUDENT_JOURNAL_PUBLICATION_DETAILS', 'STUDENT_CONFERENCE_PROCEEDING_DETAILS',
                              'STUDENT_PATENT_DETAILS', 'PARTICIPATED_EVENTS')
      AND udmc.user_type = 'student'
      AND udmc.active = 1
    GROUP BY v.ukid
) im ON im.ukid = sp.ukid
LEFT JOIN (
    -- student profile custom fields; list fields store the list item id
    SELECT v.ukid,
           MAX(CASE WHEN f.identifier = 'GRADUATION_MODE_OF_STUDY' THEN li.name END) AS mode_of_study,
           MAX(CASE WHEN f.identifier = 'PHD_STUDENT_TYPE'         THEN li.name END) AS phd_type
    FROM user_details_master_field_value v
    JOIN user_details_master_field f                ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id AND li.id = v.value
    WHERE f.identifier IN ('GRADUATION_MODE_OF_STUDY', 'PHD_STUDENT_TYPE')
    GROUP BY v.ukid
) cf ON cf.ukid = sp.ukid
LEFT JOIN (
    -- major / minor specialisations opted by the student
    SELECT pss.ukid,
           GROUP_CONCAT(DISTINCT CASE WHEN psm.specialisation_type = 'MAJOR' THEN sx.name END ORDER BY sx.name SEPARATOR ', ') AS major_name,
           GROUP_CONCAT(DISTINCT CASE WHEN psm.specialisation_type = 'MINOR' THEN sx.name END ORDER BY sx.name SEPARATOR ', ') AS minor_name
    FROM programme_specialisation_student pss
    JOIN programme_specialisation_mapping psm ON psm.id = pss.programme_specialisation_mapping_id AND IFNULL(psm.is_deleted, 0) = 0
    JOIN specialisation sx                    ON sx.id = psm.specialisation_id
    GROUP BY pss.ukid
) ss ON ss.ukid = sp.ukid
LEFT JOIN (
    -- first / latest regular term the student had courses in (course registration or exam enrolment)
    SELECT sc.ukid,
           CAST(SUBSTRING(MIN(CONCAT(DATE_FORMAT(t.starts, '%Y%m%d'), t.acad_year_start * 100 + t.sequence * 10)), 9) AS UNSIGNED) AS first_period,
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
  AND (rp.ukid IS NOT NULL OR pt.name = 'PhD')                                -- research students: project entered or PhD programme
ORDER BY `Academic Period` DESC, `Student ID`, `Research Topic`;
