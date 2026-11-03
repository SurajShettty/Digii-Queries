-- Module: Curriculum — Curriculum Min / Max Courses Report
-- One row per Department / Program / Batch / Semester / Enrollment Type with the
-- minimum and maximum number of courses a student must register for, as configured
-- on the curriculum cluster sets. Used to check how many courses a student was
-- supposed to take per the curriculum vs how many they actually registered for.
--
-- Schema path (same curriculum mapping tree as curriculum_report.sql):
--   curriculum (c)              -> programme_id, batch_year, specialisation mapping
--     curriculum_cluster (cc)   -> sequence (= semester sequence)
--       curriculum_cluster_set (ccs) -> course_registration_type_id, min_courses, max_courses
--   course_registration_type (crt) -> Core / Programme Electives / ... (the "Enrollment Type")
--   Department is the programme's owning department (p.department_id).
--
-- Notes:
--   - A semester can have more than one cluster set of the same enrollment type
--     (e.g. two elective baskets), so min/max are SUMMED per enrollment type.
--     `Cluster Sets` shows how many sets were added together.
--   - A programme + batch can have separate curricula per specialisation; these are
--     kept as separate rows (Specialisation column) so they are not added together.
--   - Min/Max NULL on a cluster set means "All courses mandatory" (as shown on the
--     front end, e.g. Core Courses), so min = max = number of courses in that set.
--   - Courses are counted per cluster set in a subquery BEFORE summing; joining
--     curriculum_course directly would repeat each set's min/max once per course.
--   - `Courses Mapped` is the number of courses available in those cluster sets
--     (the pool), not the number a student must take.
--   ccs.is_deleted = 0       -> exclude removed cluster sets
--   cc.sequence IS NOT NULL  -> exclude un-sequenced clusters

SELECT
    d.department_name            AS `Department`,
    p.programme_name             AS `Program`,
    c.batch_year                 AS `Batch`,
    s.name                       AS `Specialisation`,
    cc.sequence                  AS `Semester`,
    crt.name                     AS `Enrollment Type`,
    SUM(COALESCE(ccs.min_courses, IFNULL(ccc.course_count, 0))) AS `Min. Courses`,
    SUM(COALESCE(ccs.max_courses, IFNULL(ccc.course_count, 0))) AS `Max. Courses`,
    COUNT(ccs.id)                AS `Cluster Sets`,
    SUM(IFNULL(ccc.course_count, 0)) AS `Courses Mapped`
FROM curriculum_cluster_set ccs
JOIN curriculum_cluster     cc  ON cc.id = ccs.curriculum_cluster_id
JOIN curriculum             c   ON c.id  = cc.curriculum_id
LEFT JOIN course_registration_type crt ON crt.id = ccs.course_registration_type_id
LEFT JOIN programme         p   ON p.programme_id  = c.programme_id
LEFT JOIN department        d   ON d.department_id = p.department_id
LEFT JOIN programme_specialisation_mapping psm ON psm.id = c.programme_specialisation_mapping_id
LEFT JOIN specialisation    s   ON s.id = psm.specialisation_id
LEFT JOIN (
    SELECT curriculum_cluster_set_id, COUNT(*) AS course_count
    FROM curriculum_course
    WHERE is_deleted = 0
    GROUP BY curriculum_cluster_set_id
) ccc ON ccc.curriculum_cluster_set_id = ccs.id
WHERE ccs.is_deleted = 0
  AND cc.sequence IS NOT NULL
GROUP BY c.id, d.department_name, p.programme_name, c.batch_year, s.name,
         cc.sequence, crt.name
ORDER BY d.department_name, p.programme_name, c.batch_year, s.name,
         cc.sequence, crt.name;
