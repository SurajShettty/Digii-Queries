-- Program Learning Outcomes report (CHEDS/KHDA format).
-- One row per programme learning outcome (Academic Period, Program Name, PLO code, PLO description).
-- PLOs come from obe_programme (Programme Outcome in Course Catalogue / OBE): Programme Outcomes (PO*) and Programme
-- Specific Outcomes (PSO*). Programme Educational Objectives (PEO*) are objectives, not learning outcomes, and are left out.
-- Outcomes are defined per programme + batch year and the same codes repeat across batches, so only the latest batch year's
-- set (up to the current year) is reported to keep codes unique per programme.
-- Academic Period = the programme's current term: latest non-additional term that has started (programme term, else
-- all-programme term of the programme's college).
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (CHEDS Semester Code list)
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    t.acad_year_start * 100 + t.sequence * 10                           AS `Academic Period`,
    LEFT(p.programme_name, 500)                                         AS `Program Name`,
    LEFT(TRIM(o.code), 100)                                             AS `PLO code`,
    LEFT(TRIM(REPLACE(REPLACE(o.description, '\r', ''), '\n', ' ')), 500) AS `PLO description`    -- line breaks flattened
FROM obe_programme o
JOIN programme p                             ON p.programme_id = o.programme_id
LEFT JOIN term t                             ON t.id = (
    -- current term of the programme
    SELECT t2.id
    FROM term t2
    WHERE (t2.programme_id = p.programme_id OR (t2.all_programmes = 1 AND t2.college_id = p.college_id))
      AND t2.additional_term = 0
      AND t2.starts <= CURDATE()
    ORDER BY t2.starts DESC, t2.id DESC
    LIMIT 1
)
WHERE o.is_deleted = 0
  AND o.type IN ('PROGRAMME_OUTCOMES', 'PROGRAMME_SPECIFIC_OUTCOMES')
  AND NULLIF(TRIM(o.description), '') IS NOT NULL
  AND o.batch_year = (
      -- latest batch year with outcomes defined for the programme
      SELECT MAX(o2.batch_year)
      FROM obe_programme o2
      WHERE o2.programme_id = o.programme_id
        AND o2.is_deleted = 0
        AND o2.type IN ('PROGRAMME_OUTCOMES', 'PROGRAMME_SPECIFIC_OUTCOMES')
        AND o2.batch_year <= YEAR(CURDATE())
  )
ORDER BY `Program Name`, o.type, LENGTH(TRIM(o.code)), `PLO code`;
