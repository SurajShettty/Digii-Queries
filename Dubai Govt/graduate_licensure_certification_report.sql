-- Graduates - Licensure / Certification (GLC) report (CHEDS/KHDA format).
-- One row per graduate licence / certificate. Graduate = student converted to alumni (alumni_profile), as in graduates_report.
-- Licences / certificates come from two sources (UNION ALL):
--   PROFILE : user_certification (profile "Certifications" section - name, issuing authority, issue month / year)
--   MOOC    : student profile custom field groups MOOC_CERTIFICATE1..5 (name, issuing institute, status of completion,
--             end date, certificate identification no.)
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (KHDA Dict)
-- Licence / Certificate award status: IP = in progress, EP = passed / awarded, EX = failed, NA = not required, UN = unknown.
-- Columns marked "Enhancement Required" / "To Be Checked" have no (reliable) source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,              -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    tr.last_period                                                      AS `Graduating Academic Period`,    -- last term the graduate was enrolled in
    tr.first_period                                                     AS `1st Academic Period`,           -- first term the graduate was enrolled in
    COALESCE(ap.registration_id, ua.registration_id)                    AS `Graduate ID`,
    pt.name                                                             AS `Graduate Level (Level Code)`,   -- To Be Checked: programme type; Level code to be mapped (KHDA Dict)
    pt.name                                                             AS `Graduate Degree (Degree Code)`, -- Degree code to be mapped (KHDA Dict, e.g. BA)
    p.programme_code                                                    AS `Graduate Program (Program Code)`, -- Program code to be mapped (KHDA Dict)
    gc.cert_name                                                        AS `License/certificate name`,
    gc.body_name                                                        AS `Licensing body name`,
    NULL                                                                AS `Licensing body website`,        -- Enhancement Required (MOOC "Certificate Key / URL" is the certificate link, not the body website)
    NULL                                                                AS `Licensing body country`,        -- Enhancement Required (country code / 'INTL'; MOOC captures only City / State)
    CASE
         WHEN gc.src = 'PROFILE' THEN
              CASE WHEN gc.award_date IS NOT NULL THEN 'EP' ELSE 'UN' END
         WHEN gc.status_text IS NULL                                     THEN 'UN'
         WHEN gc.status_text LIKE '%progress%'
           OR gc.status_text LIKE '%ongoing%'
           OR gc.status_text LIKE '%pursuing%'                           THEN 'IP'
         WHEN gc.status_text LIKE '%fail%'                               THEN 'EX'
         WHEN gc.status_text LIKE '%not req%'
           OR gc.status_text IN ('NA', 'N/A')                            THEN 'NA'
         WHEN gc.status_text LIKE '%complete%'
           OR gc.status_text LIKE '%pass%'
           OR gc.status_text LIKE '%award%'
           OR gc.status_text LIKE '%cleared%'                            THEN 'EP'
         ELSE 'UN'
    END                                                                 AS `Licensure/Certificate award status`, -- To Be Checked: MOOC status is free text
    DATE_FORMAT(gc.award_date, '%d/%m/%Y')                              AS `Licensure/Certificate award date`,  -- PROFILE: 1st of issue month; MOOC: end date
    gc.cert_number                                                      AS `License/certificate number`,
    NULL                                                                AS `Comments`,
    (SELECT t.acad_year_start * 100 + t.sequence * 10                   -- term running on the report date (programme term preferred over all-programme term)
     FROM term t
     WHERE CURDATE() BETWEEN DATE(t.starts) AND DATE(t.ends)
       AND (t.programme_id = p.programme_id OR (t.all_programmes = 1 AND t.college_id = c.college_id))
     ORDER BY (t.programme_id = p.programme_id) DESC, t.starts DESC
     LIMIT 1)                                                           AS `Submission Term`,
    DATE_FORMAT(GREATEST(COALESCE(gc.updated_at, ap.updated_timestamp, ap.created_timestamp),
                         COALESCE(ap.updated_timestamp, ap.created_timestamp)),
                '%Y-%m-%d')                                             AS `Last Updated`
FROM (
    -- profile certifications (no timestamps on the table)
    SELECT 'PROFILE'                                                    AS src,
           uc.ukid,
           uc.id                                                        AS sort_key,
           NULLIF(TRIM(uc.name), '')                                    AS cert_name,
           NULLIF(TRIM(uc.authority), '')                               AS body_name,
           NULL                                                         AS status_text,
           CASE WHEN TRIM(uc.startYear) REGEXP '^[0-9]{4}$' THEN
                STR_TO_DATE(CONCAT(TRIM(uc.startYear), '-',
                                   CASE WHEN TRIM(uc.startMonth) REGEXP '^[0-9]{1,2}$' THEN TRIM(uc.startMonth)
                                        WHEN NULLIF(TRIM(uc.startMonth), '') IS NOT NULL   -- month name, e.g. 'January' / 'Jan'
                                        THEN MONTH(STR_TO_DATE(CONCAT('01 ', LEFT(TRIM(uc.startMonth), 3), ' 2000'), '%d %b %Y'))
                                        ELSE 1
                                   END, '-01'), '%Y-%m-%d')
           END                                                          AS award_date,
           NULL                                                         AS cert_number,
           NULL                                                         AS updated_at
    FROM user_certification uc
    JOIN alumni_profile apc ON apc.ukid = uc.ukid
    WHERE NULLIF(TRIM(uc.name), '') IS NOT NULL

    UNION ALL

    -- MOOC certificate custom field groups; identifier = MOOC_CERTIFICATE<slot>_<attribute>
    SELECT 'MOOC'                                                       AS src,
           m.ukid,
           m.slot                                                       AS sort_key,
           m.cert_name,
           m.body_name,
           m.status_text,
           CASE WHEN m.end_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN DATE(LEFT(m.end_date, 10)) END AS award_date,
           m.cert_number,
           m.updated_at
    FROM (
        SELECT v.ukid,
               CAST(SUBSTRING(f.identifier, 17, 1) AS UNSIGNED)                                                           AS slot,
               MAX(CASE WHEN SUBSTRING(f.identifier, 19) = 'NAME_OF_THE_CERTIFICATE'               THEN NULLIF(TRIM(v.value), '') END) AS cert_name,
               MAX(CASE WHEN SUBSTRING(f.identifier, 19) = 'NAME_OF_INSTITUTE_ISSUING_CERTIFICATE' THEN NULLIF(TRIM(v.value), '') END) AS body_name,
               MAX(CASE WHEN SUBSTRING(f.identifier, 19) = 'STATUS_OF_COMPLETION'                  THEN NULLIF(TRIM(v.value), '') END) AS status_text,
               MAX(CASE WHEN SUBSTRING(f.identifier, 19) = 'END_DATE'                              THEN NULLIF(TRIM(v.value), '') END) AS end_date,
               MAX(CASE WHEN SUBSTRING(f.identifier, 19) = 'CERTIFICATE_IDENTIFICATION_NO'         THEN NULLIF(TRIM(v.value), '') END) AS cert_number,
               MAX(COALESCE(v.edited_timestamp, v.modified_timestamp, v.created_timestamp))                                AS updated_at
        FROM user_details_master_field_value v
        JOIN alumni_profile apm          ON apm.ukid = v.ukid
        JOIN user_details_master_field f ON f.id = v.field_id
        WHERE f.identifier LIKE 'MOOC\_CERTIFICATE_\_%'
          AND IFNULL(v.type, '') <> 'DRAFT'
        GROUP BY v.ukid, CAST(SUBSTRING(f.identifier, 17, 1) AS UNSIGNED)
    ) m
    WHERE m.cert_name IS NOT NULL
) gc
JOIN alumni_profile ap           ON ap.ukid = gc.ukid
JOIN user_attributes ua          ON ua.ukid = ap.ukid
LEFT JOIN student_profile sp     ON sp.ukid = ap.ukid
LEFT JOIN college c              ON c.college_id = COALESCE(sp.college_id, ua.college_id)
LEFT JOIN programme p            ON p.programme_id = COALESCE(ap.programme_id, sp.programme_id)
LEFT JOIN programme_types pt     ON pt.id = p.programme_type_id
LEFT JOIN (
    -- terms in which the graduate was actually enrolled in courses (exam programme enrolment with enrolled courses)
    SELECT et.ukid,
           CAST(SUBSTRING(MIN(CONCAT(DATE_FORMAT(et.starts, '%Y%m%d'), et.period_code)), 9) AS UNSIGNED) AS first_period,
           CAST(SUBSTRING(MAX(CONCAT(DATE_FORMAT(et.starts, '%Y%m%d'), et.period_code)), 9) AS UNSIGNED) AS last_period
    FROM (
        SELECT DISTINCT spe.ukid, t.id AS term_id, t.starts,
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
ORDER BY `Graduating Academic Period` DESC, `Graduate ID`, gc.src, gc.sort_key;
