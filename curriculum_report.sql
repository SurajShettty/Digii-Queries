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
	t.name as `Term`,
    d.department_name        AS `Department`,
    p.programme_name         AS `Program`,
    c.batch_year             AS `Batch`,
    coalesce(ccc.course_name,cv.course_name)          AS `Course Name`,
    ccc.course_code          AS `Course Code`,
    coalesce(ccc.course_credits,cv.course_credits)       AS `Course Credit`,
    crt.name                 AS `Enrollment Type`,
    cc.sequence              AS `Semester Sequence`
FROM curriculum_course ccc
left join course_version cv on cv.id = ccc.course_version_id
left join term_course tc on tc.course_version_id = cv.id
left join term t on t.id = tc.term_id
JOIN curriculum_cluster_set ccs ON ccs.id = ccc.curriculum_cluster_set_id
JOIN curriculum_cluster     cc  ON cc.id  = ccs.curriculum_cluster_id
JOIN curriculum             c   ON c.id   = cc.curriculum_id
LEFT JOIN course_registration_type crt ON crt.id = ccs.course_registration_type_id
LEFT JOIN programme         p   ON p.programme_id = c.programme_id
LEFT JOIN department        d   ON d.department_id = p.department_id
WHERE ccc.is_deleted = 0
  AND cc.sequence IS NOT NULL
  AND ccc.course_code IS NOT NULL and tc.term_id in (137,130)
ORDER BY d.department_name, p.programme_name, c.batch_year,
         cc.sequence, crt.name, ccc.course_code;





SELECT 
    term_id,
    ccs.name AS ccs_name,
    p.programme_name,
    dd.department_name AS programme_dept,
    c.batch_year,
    cc.sequence,
    crt.name AS enrolment_type,
    IF(cc.is_term_dependent = 1,
        'Term Specific',
        'Term Independent') curriculum_type,
    s.name specialisation,
    psm.specialisation_type,
    ccc.course_code,
    cv.id AS course_version_id,
    cv.version,
    cv.course_name,
    cct.name AS component_type,
    cco.course_credits AS component_credits,
    d.department_name AS course_offered_by_dept,
    ccc.course_credits,
    ccs.min_courses,
    ccs.max_courses,
    ccs.min_credits,
    ccs.max_credits
FROM
    term_programme_batch tpb
        LEFT JOIN
    curriculum c ON c.programme_id = tpb.programme_id
        AND c.batch_year = tpb.batch
        LEFT JOIN
    curriculum_cluster cc ON cc.curriculum_id = c.id
        LEFT JOIN
    curriculum_cluster_set ccs ON ccs.curriculum_cluster_id = cc.id
        LEFT JOIN
    course_registration_type crt ON crt.id = ccs.course_registration_type_id
        LEFT JOIN
    programme p ON p.programme_id = c.programme_id
        LEFT JOIN
    department dd ON dd.department_id = p.department_id
        LEFT JOIN
    curriculum_course ccc ON ccc.curriculum_cluster_set_id = ccs.id
        LEFT JOIN
    course_version cv ON cv.id = ccc.course_version_id
        LEFT JOIN
    course cccc ON cv.course_id = cccc.course_id
        LEFT JOIN
    department d ON d.department_id = cccc.department_id
        LEFT JOIN
    programme_specialisation_mapping psm ON psm.id = c.programme_specialisation_mapping_id
        LEFT JOIN
    specialisation s ON psm.specialisation_id = s.id
        LEFT JOIN
    course_component cco ON cco.course_version_id = cv.id
        LEFT JOIN
    course_component_type cct ON cct.id = cco.course_component_type_id
WHERE
    sequence IS NOT NULL
        AND ccc.course_code IS NOT NULL
        AND ccs.is_deleted = 0
        AND term_id = 130;