-- Module: Curriculum — Curriculum Report
-- One row per curriculum course mapping with:
--   Department, Program, Batch, Course Name, Course Code, Course Credit,
--   Enrollment Type (Core / Optional / ...), Semester Sequence.
--
-- Schema path (curriculum mapping tree):
--   curriculum (c)              -> programme_id, batch_year
--     curriculum_cluster (cc)   -> sequence  (= semester sequence)
--       curriculum_cluster_set (ccs) -> course_registration_type_id
--         curriculum_course (ccc)    -> the mapped course (code/name/credits)
--   course_registration_type (crt) -> Core / Optional (the "Enrollment Type")
--   Department is the programme's owning department (p.department_id).
--
-- Notes:
--   ccc.is_deleted = 0       -> exclude removed course mappings
--   cc.sequence IS NOT NULL  -> exclude un-sequenced clusters
--   ccc.course_code IS NOT NULL -> exclude empty cluster-sets

SELECT
    d.department_name        AS `Department`,
    p.programme_name         AS `Program`,
    c.batch_year             AS `Batch`,
    ccc.course_name          AS `Course Name`,
    ccc.course_code          AS `Course Code`,
    ccc.course_credits       AS `Course Credit`,
    crt.name                 AS `Enrollment Type`,
    cc.sequence              AS `Semester Sequence`
FROM curriculum_course ccc
JOIN curriculum_cluster_set ccs ON ccs.id = ccc.curriculum_cluster_set_id
JOIN curriculum_cluster     cc  ON cc.id  = ccs.curriculum_cluster_id
JOIN curriculum             c   ON c.id   = cc.curriculum_id
LEFT JOIN course_registration_type crt ON crt.id = ccs.course_registration_type_id
LEFT JOIN programme         p   ON p.programme_id = c.programme_id
LEFT JOIN department        d   ON d.department_id = p.department_id
WHERE ccc.is_deleted = 0
  AND cc.sequence IS NOT NULL
  AND ccc.course_code IS NOT NULL
ORDER BY d.department_name, p.programme_name, c.batch_year,
         cc.sequence, crt.name, ccc.course_code;
