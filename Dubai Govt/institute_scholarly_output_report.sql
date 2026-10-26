-- Institute - Scholarly Output (formerly Publications) report (CHEDS/KHDA format).
-- One row per faculty/staff journal publication entry from the ePortfolio cluster JOURNAL_PUBLICATION_DETAILS.
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet and are returned as NULL.
SELECT
    c.university_code                                                   AS `Institution Code`,           -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    YEAR(CURDATE())                                                     AS `Year`,                       -- reporting year
    ua.registration_id                                                  AS `Faculty/Employee ID`,
    NULL                                                                AS `Researcher Type(Researcher Code)`, -- Enhancement Required
    CASE WHEN NULLIF(TRIM(p.authors), '') IS NULL THEN NULL
         ELSE LENGTH(p.authors) - LENGTH(REPLACE(p.authors, ',', '')) + 1
    END                                                                 AS `Number of Authors`,
    p.title                                                             AS `Title of Published Work`,
    COALESCE(NULLIF(TRIM(p.citations), ''), '0')                        AS `Total citations`,
    YEAR(STR_TO_DATE(p.publication_date, '%Y-%m-%d'))                   AS `Year of Publication`,
    NULL                                                                AS `Type of Publication(Publication Code)`, -- Enhancement Required
    NULL                                                                AS `Research area of publication`,  -- Enhancement Required
    COALESCE(NULLIF(TRIM(p.journal_name), ''), p.publisher)             AS `Publisher`,
    NULL                                                                AS `Referee Indicator`,             -- To Be Checked
    NULL                                                                AS `Reasons for NON-SCOPUS entries`, -- To Be Checked
    DATE_FORMAT(p.last_updated, '%Y-%m-%d')                             AS `Last Updated`
FROM (
    SELECT
        v.ukid,
        v.cluster_entry_id,
        udmc.college_id,
        MAX(CASE WHEN f.identifier = 'TITLE_OF_PAPER'     THEN v.value END) AS title,
        MAX(CASE WHEN f.identifier = 'AUTHORS'            THEN v.value END) AS authors,
        MAX(CASE WHEN f.identifier = 'NUMBER_OF_CITATION' THEN v.value END) AS citations,
        MAX(CASE WHEN f.identifier = 'PUBLICATION_DATE'   THEN v.value END) AS publication_date,
        MAX(CASE WHEN f.identifier = 'JOURNAL_NAME'       THEN v.value END) AS journal_name,
        MAX(CASE WHEN f.identifier = 'PUBLISHER'          THEN v.value END) AS publisher,
        MAX(v.modified_timestamp)                                           AS last_updated
    FROM user_details_master_cluster_entry_field_value v
    JOIN user_details_master_cluster_entry udmce ON udmce.id = v.cluster_entry_id
    JOIN user_details_master_cluster udmc        ON udmc.id = udmce.cluster_id
    JOIN user_details_master_field f             ON f.id = v.field_id
    WHERE udmc.identifier = 'JOURNAL_PUBLICATION_DETAILS'
      AND udmc.user_type IN ('faculty', 'administrator')
      AND udmc.active = 1
    GROUP BY v.ukid, v.cluster_entry_id, udmc.college_id
) p
JOIN user_attributes ua ON ua.ukid = p.ukid
LEFT JOIN college c     ON c.college_id = p.college_id
WHERE NULLIF(TRIM(p.title), '') IS NOT NULL
ORDER BY ua.registration_id, `Year of Publication` DESC;
