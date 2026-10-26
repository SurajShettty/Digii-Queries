-- Students - Scholarship report (CHEDS/KHDA format).
-- One row per student per scholarship per fee structure (academic period) = active (not deleted) scholarship applied on a
-- valid (not invalidated) student fee.
-- Academic Period comes from the fee structure: academic year start (fee structure academic year, else derived from the
-- batch year + fee sequence) and term within that year (TERM_WISE fee plans; YEARLY / ONE_TIME plans report term 1).
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (KHDA Dict)
-- Scholarship Amount = scholarship amount applied across all fee heads; Scholarship Value = % of the tuition fee covered by
-- the tuition fee head(s) of the scholarship (fee types named like '%TUITION%').
-- Student details follow the Students - Enrollment report.
-- Columns marked "Enhancement Required" / "To Be Checked" have no (reliable) source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,              -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    (COALESCE(CAST(NULLIF(LEFT(TRIM(fs.academic_year), 4), '') AS UNSIGNED),
              CASE fpb.creation_method
                   WHEN 'TERM_WISE' THEN fs.batch_year + FLOOR((fs.sequence - 1) / tp.terms_per_year)
                   WHEN 'YEARLY'    THEN fs.batch_year + FLOOR(fs.sequence) - 1
                   ELSE fs.batch_year
              END) * 100
     + CASE WHEN fpb.creation_method = 'TERM_WISE'
            THEN (MOD(FLOOR(fs.sequence) - 1, tp.terms_per_year) + 1) * 10
            ELSE 10
       END)                                                             AS `Academic Period`,               -- To Be Checked: derived from the fee structure the scholarship is applied on
    COALESCE(NULLIF(TRIM(sp.registration_id), ''), ua.registration_id)  AS `Student ID`,
    '999999999999999'                                                   AS `Emirates ID`,                   -- Enhancement Required (999999999999999 when not available)
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
    s.name                                                              AS `Scholarship Type`,              -- To Be Checked: scholarship name; Scholarship Type code to be mapped (CHEDS list)
    CASE s.type
         WHEN 'WAIVER' THEN 'IN'                                                                            -- waiver = funded by the institution itself
         ELSE NULLIF(TRIM(s.sponsorer), '')
    END                                                                 AS `Scholarship Provider Type`,     -- To Be Checked: sponsor text to be mapped (CHEDS Provider Type list)
    CASE s.type
         WHEN 'WAIVER' THEN c.college_name
         ELSE COALESCE(NULLIF(TRIM(s.sponsorer), ''), c.college_name)
    END                                                                 AS `Scholarship Provider Name`,     -- To Be Checked: sponsor name only captured as free text
    ROUND(sch.tuition_amount * 100 / NULLIF(tf.tuition_fee, 0), 2)      AS `Scholarship Value`,             -- % of tuition fee covered; To Be Checked when the scholarship has no tuition fee head
    ROUND(sch.amount, 2)                                                AS `Scholarship Amount`,
    NULL                                                                AS `Scholarship Duration`,          -- Enhancement Required (Scholarship Duration code not captured)
    DATE_FORMAT(GREATEST(COALESCE(ss.modified_timestamp, ss.created_timestamp),
                         COALESCE(sch.last_modified, ss.modified_timestamp, ss.created_timestamp)),
                '%Y-%m-%d')                                             AS `Last Updated`
FROM student_scholarship ss
JOIN scholarship s               ON s.id = ss.scholarship_id
JOIN student_fee sf              ON sf.id = ss.student_fee_id AND IFNULL(sf.invalidated, 0) = 0
JOIN fee_structure fs            ON fs.id = sf.fee_structure_id
LEFT JOIN fee_programme_batch fpb ON fpb.id = fs.fee_programme_batch_id
JOIN student_profile sp          ON sp.ukid = sf.ukid
JOIN user_attributes ua          ON ua.ukid = sp.ukid
LEFT JOIN college c              ON c.college_id = COALESCE(sp.college_id, ua.college_id, s.college_id)
LEFT JOIN programme p            ON p.programme_id = COALESCE(fs.programme_id, sp.programme_id)
LEFT JOIN programme_types pt     ON pt.id = p.programme_type_id
LEFT JOIN (
    -- regular terms per academic year of the programme (e.g. 8 semesters / 4 years -> 2)
    SELECT p2.programme_id,
           GREATEST(1, COALESCE(ROUND(p2.system_count / NULLIF(p2.duration_years, 0)), 2)) AS terms_per_year
    FROM programme p2
) tp ON tp.programme_id = p.programme_id
JOIN (
    -- scholarship amount per student scholarship: all fee heads / tuition fee heads only
    SELECT ssc.student_scholarship_id,
           SUM(COALESCE(ssc.amount, 0))                                              AS amount,
           SUM(CASE WHEN ft.name LIKE '%TUITION%' THEN COALESCE(ssc.amount, 0) ELSE 0 END) AS tuition_amount,
           MAX(ssc.modified_timestamp)                                               AS last_modified
    FROM student_scholarship_component ssc
    LEFT JOIN scholarship_component sc ON sc.id = ssc.scholarship_component_id
    LEFT JOIN fee_type ft              ON ft.id = sc.fee_type_id
    WHERE IFNULL(ssc.deleted, 0) = 0
    GROUP BY ssc.student_scholarship_id
) sch ON sch.student_scholarship_id = ss.id
LEFT JOIN (
    -- tuition fee charged on the student fee (before scholarship / waiver)
    SELECT sfc.student_fee_id,
           SUM(sfc.initial_amount) AS tuition_fee
    FROM student_fee_component sfc
    JOIN fee_type ft ON ft.id = sfc.entity_id
    WHERE sfc.type = 'FEE_TYPE'
      AND ft.name LIKE '%TUITION%'
    GROUP BY sfc.student_fee_id
) tf ON tf.student_fee_id = sf.id
LEFT JOIN (
    -- nationality from the student profile custom fields
    SELECT v.ukid,
           MAX(NULLIF(TRIM(v.value), '')) AS nationality
    FROM user_details_master_field_value v
    JOIN user_details_master_field f ON f.id = v.field_id
    WHERE f.identifier = 'NATIONALITY'
    GROUP BY v.ukid
) cf ON cf.ukid = sp.ukid
WHERE IFNULL(ss.is_deleted, 0) = 0
  AND sch.amount > 0                                                          -- scholarship actually applied
ORDER BY `Academic Period` DESC, `Student ID`, `Scholarship Type`;
