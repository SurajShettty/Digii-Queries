-- Module: Curriculum — Programme Credit Summary Report
-- One row per School (Department) / Program / Year of Admission (Batch) / Enrollment
-- Type, with the total course credits currently MAPPED in the curriculum for that
-- type (Core Courses / Programme Electives / Open Electives / Internship / Audit /
-- Zero Credit — whatever types exist in course_registration_type, unpivoted rather
-- than hardcoded as columns).
--
-- WHY THIS QUERY EXISTS / WHAT IT IS NOT:
--   The "Minimum Credit Requirement for Award of Degree" basket structure used in
--   planning sheets (University Core, Program Foundation, Program Core/Major,
--   Program Hons, Specialization Tracks, Minor, Internship/Capstone, etc.) is
--   NOT captured anywhere in this database:
--     - curriculum_cluster_set.min_credits / max_credits are NULL on every row
--       (checked DB-wide: 0 of 16,216 rows populated).
--     - course_registration_type only has 6 generic values (see below) — no
--       University Core / Foundation / Major / Hons / Minor / Specialization split.
--     - credit_matrix_policy / credit_matrix_policy_rule / credit_policy_mapping
--       (tables that look purpose-built for exactly this) are completely empty.
--   So that basket breakdown lives only in the planning spreadsheet, not in Digii.
--
--   This query instead reports the closest thing that DOES exist: actual credits
--   of courses mapped into the curriculum, grouped by the 6 real registration
--   types. Treat it as a sanity/reconciliation check against the planning sheet,
--   not a like-for-like replacement — in particular:
--     - "Programme Electives" / "Open Electives" / "Audit" totals are the size of
--       the elective POOL offered, not the credits a student is required to take
--       from that pool (min/max course counts per cluster exist but are not
--       reliably populated either).
--     - "Core Courses" here is a single flat bucket; it does not distinguish
--       University Core vs Foundation vs Program Core vs Program Hons the way
--       the planning sheet does, so it will not numerically match those rows.
--
-- Schema path (same curriculum mapping tree as curriculum_report.sql):
--   curriculum (c)              -> programme_id, batch_year
--     curriculum_cluster (cc)   -> sequence (semester) / is_term_dependent
--       curriculum_cluster_set (ccs) -> course_registration_type_id
--         curriculum_course (ccc)    -> the mapped course (code/name/credits)
--   course_registration_type (crt) -> Core Courses / Programme Electives /
--                                     Open Electives / Internship / Audit / Zero Credit
--   School = the programme's owning department (p.department_id).
--
-- Notes:
--   ccc.is_deleted = 0 / ccs.is_deleted = 0 -> exclude removed mappings.
--   ccc.course_code IS NOT NULL             -> exclude empty cluster-sets.
--   No filter on cc.sequence: many curricula map the whole degree under a single
--   term-independent cluster (sequence IS NULL), so filtering it out would drop
--   entire programs.

SELECT p.programme_name, d.department_name, c.batch_year, COALESCE(s.name,'Major') specialisation, crt.registration_type course_reg_type, cc.sequence, COUNT(DISTINCT cco.id) course_count,SUM(COALESCE(cco.course_credits, cv.course_credits))   AS total_credits
FROM curriculum_course cco
LEFT JOIN curriculum_cluster_set ccs ON cco.curriculum_cluster_set_id = ccs.id
LEFT JOIN curriculum_cluster cc ON cc.id = ccs.curriculum_cluster_id
LEFT JOIN curriculum c ON c.id = cc.curriculum_id
LEFT JOIN course_registration_type crt ON crt.id = ccs.course_registration_type_id
LEFT JOIN programme p ON p.programme_id = c.programme_id
LEFT JOIN programme_specialisation_mapping psm ON psm.id = c.programme_specialisation_mapping_id
LEFT JOIN specialisation s ON psm.specialisation_id = s.id
LEFT JOIN department d ON d.department_id = p.department_id
LEFT JOIN course_version cv ON cv.id = cco.course_version_id
WHERE 
is_term_dependent =1 AND cco.is_deleted = 0 
-- AND programme_name = 'Bachelor of Technology (Hons) Computer Science and Engineering (Data Science)' AND c.batch_year = 2023
GROUP BY department_name, p.programme_name, c.batch_year, s.name, crt.registration_type, cc.sequence



SELECT
    p.programme_name,
    d.department_name,
    c.batch_year,
    COALESCE(s.name,'Major') specialisation,
    crt.registration_type                      AS course_reg_type,
    cc.sequence,
    COALESCE(cv.course_code,cco.course_code) course_code,
    COALESCE(cv.course_name,cco.course_name) course_name,
    COALESCE(cv.course_credits,cco.course_credits) AS course_credits
FROM curriculum_course cco
LEFT JOIN curriculum_cluster_set ccs ON cco.curriculum_cluster_set_id = ccs.id
LEFT JOIN curriculum_cluster     cc  ON cc.id  = ccs.curriculum_cluster_id
LEFT JOIN curriculum              c  ON c.id   = cc.curriculum_id
LEFT JOIN course_registration_type crt ON crt.id = ccs.course_registration_type_id
LEFT JOIN programme                p  ON p.programme_id = c.programme_id
LEFT JOIN programme_specialisation_mapping psm ON psm.id = c.programme_specialisation_mapping_id
LEFT JOIN specialisation           s  ON psm.specialisation_id = s.id
LEFT JOIN department               d  ON d.department_id = p.department_id
LEFT JOIN course_version           cv ON cv.id = cco.course_version_id
WHERE cco.is_deleted = 0 AND is_term_dependent =1
AND programme_name = 'Bachelor of Technology (Hons) Computer Science and Engineering (Data Science)' AND c.batch_year = 2023 AND s.name = 'Economics'
ORDER BY d.department_name, p.programme_name, c.batch_year, s.name, crt.registration_type, cc.sequence, cco.course_code;
