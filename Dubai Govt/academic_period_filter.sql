-- Academic Period filter (CHEDS/KHDA reports).
-- One row per academic period: feeds the Academic Period placeholder / dropdown used by the Dubai Govt reports.
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510 (same code as the reports).
-- Academic years are coded as <start year><end year YY>, e.g. 2025-26 -> 202526 (same code as the Institute Overview report).
-- Terms of all colleges / programmes with the same year + sequence share one period; their names are listed together.
-- Supplementary (additional) terms are flagged, not dropped: the reports' period code does not tell them apart.
-- Usage in a report: AND t.acad_year_start * 100 + t.sequence * 10 = {{academic_period}}
--                    AND t.acad_year_start * 100 + MOD(t.acad_year_start + 1, 100) = {{academic_year}}
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    t.acad_year_start * 100 + t.sequence * 10                           AS `Academic Period`,           -- placeholder value, e.g. 202510
    CONCAT(t.acad_year_start, '-', LPAD(MOD(t.acad_year_start + 1, 100), 2, '0'),
           ' Term ', t.sequence)                                        AS `Academic Period Label`,     -- e.g. 2025-26 Term 1
    t.acad_year_start * 100 + MOD(t.acad_year_start + 1, 100)           AS `Academic Year`,             -- e.g. 202526
    CONCAT(t.acad_year_start, '-', LPAD(MOD(t.acad_year_start + 1, 100), 2, '0')) AS `Academic Year Label`, -- e.g. 2025-26
    t.sequence                                                          AS `Term Sequence`,
    GROUP_CONCAT(DISTINCT t.name ORDER BY t.name SEPARATOR ', ')        AS `Term Names`,
    MAX(IFNULL(t.additional_term, 0) = 1)                               AS `Has Supplementary Term`,
    DATE_FORMAT(MIN(t.starts), '%Y-%m-%d')                              AS `Starts`,
    DATE_FORMAT(MAX(t.ends), '%Y-%m-%d')                                AS `Ends`,
    MAX(t.starts <= CURDATE() AND (t.ends IS NULL OR DATE(t.ends) >= CURDATE())) AS `Is Current`
FROM term t
WHERE t.acad_year_start IS NOT NULL
  AND t.sequence IS NOT NULL
GROUP BY t.acad_year_start, t.sequence
ORDER BY t.acad_year_start DESC, t.sequence DESC;
