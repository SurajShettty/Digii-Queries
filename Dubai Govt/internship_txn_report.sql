-- INTERNSHIP_TXN report (Placement module).
-- One row per student internship = placement application on a job whose placement type is an INTERNSHIP type
-- (Summer / Winter Internship, Contract to hire) where the student was Selected / PLACED.
-- Academic Period = term (of the student's batch / programme, else an all-programme term) running on the internship start date,
-- coded YYYYSS as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510.
-- Start Date = job joining date, falling back to the application date (date the student was selected).
-- Internship Status (calculated from start date; end date not captured): CN = offer rejected, PL = not yet started, ON = started.
-- Columns marked "Custom Field - Development Required" have no source field yet and are returned as NULL.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    (SELECT t.acad_year_start * 100 + t.sequence * 10
     FROM term t
     WHERE DATE(COALESCE(j.joining_date, pa.modified_timestamp, pa.created_timestamp)) BETWEEN DATE(t.starts) AND DATE(t.ends)
       AND (EXISTS (SELECT 1 FROM term_programme_batch b WHERE b.term_id = t.id AND b.programme_id = sp.programme_id)
            OR EXISTS (SELECT 1 FROM term_programme tp WHERE tp.term_id = t.id AND tp.programme_id = sp.programme_id)
            OR t.programme_id = sp.programme_id
            OR (t.all_programmes = 1 AND t.college_id = sp.college_id))
     -- student's batch term first, then programme term, then all-programme term
     ORDER BY EXISTS (SELECT 1 FROM term_programme_batch b
                      WHERE b.term_id = t.id AND b.programme_id = sp.programme_id AND b.batch = sp.year_of_joining) DESC,
              IFNULL(t.all_programmes, 0), IFNULL(t.additional_term, 0), DATEDIFF(t.ends, t.starts), t.starts DESC
     LIMIT 1)                                                           AS `Academic Period`,
    COALESCE(NULLIF(TRIM(sp.registration_id), ''), ua.registration_id)  AS `Person Id`,
    p.programme_name                                                    AS `Program Name`,
    TRIM(po.name)                                                       AS `Internship Organization`,
    DATE_FORMAT(COALESCE(j.joining_date, pa.modified_timestamp, pa.created_timestamp), '%d-%m-%Y') AS `Start Date`,
    s.name                                                              AS `Internship Sector`,
    po.type                                                             AS `Internship Industry`,             -- Organization Type
    NULL                                                                AS `Internship Hours per Week`,       -- Custom Field - Development Required
    ptp.name                                                            AS `Internship Type`,                 -- Placement Type (to be configured per CHEDS internship type)
    CASE WHEN COALESCE(j.ctc, j.maximum_ctc_range, j.minimum_ctc_range, 0) > 0
         THEN 'Paid' ELSE 'Unpaid' END                                  AS `Paid or Unpaid Indicator`,        -- Development Required: derived from job CTC
    NULL                                                                AS `Internship Credits`,              -- Custom Field - Development Required
    NULL                                                                AS `Employer Satisfaction Score`,     -- Development Required (application level)
    NULL                                                                AS `Course Code`,                     -- Requires AMS sync
    NULL                                                                AS `End Date`,                        -- Field to be introduced based on joining
    NULL                                                                AS `Supervisor Name at Organization`, -- Custom Field - Development Required
    NULL                                                                AS `Supervisor Email at Organization`,   -- Custom Field - Development Required
    NULL                                                                AS `Supervisor Contact at Organization`, -- Custom Field - Development Required
    NULL                                                                AS `Supervisor Name at Institution`,  -- Custom Field - Development Required
    NULL                                                                AS `Supervisor Email at Institution`, -- Custom Field - Development Required
    NULL                                                                AS `Supervisor Contact at Institution`, -- Custom Field - Development Required
    CASE
         WHEN os.name IN ('Reject', 'System Rejected') THEN 'CN'
         WHEN DATE(COALESCE(j.joining_date, pa.modified_timestamp, pa.created_timestamp)) > CURDATE() THEN 'PL'
         ELSE 'ON'
    END                                                                 AS `Internship Status`,
    NULL                                                                AS `Payment Organizer`,               -- Custom Field - Development Required
    NULL                                                                AS `Organization Trade License`,      -- Custom Field - Development Required
    NULL                                                                AS `Organization Address`,            -- Custom Field - Development Required
    NULL                                                                AS `Organization Emirate`             -- Custom Field - Development Required
FROM placement_application pa
JOIN placement_job j                        ON j.id = pa.job_id AND IFNULL(j.is_deleted, 0) = 0
JOIN placement_types ptp                    ON ptp.id = j.placement_type_id AND ptp.type = 'INTERNSHIP'
JOIN placement_application_status ast       ON ast.id = pa.status_id AND ast.name IN ('Selected', 'PLACED')
LEFT JOIN placement_offer_status os         ON os.id = pa.offer_status_id
JOIN student_profile sp                     ON sp.ukid = pa.ukid
JOIN user_attributes ua                     ON ua.ukid = sp.ukid
LEFT JOIN programme p                       ON p.programme_id = sp.programme_id
LEFT JOIN placement_organization po         ON po.id = j.organization_id
LEFT JOIN placement_organization_sector s   ON s.id = po.sector_id
WHERE IFNULL(pa.is_deleted, 0) = 0
ORDER BY `Academic Period` DESC, `Person Id`, `Internship Organization`;
