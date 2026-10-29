-- Course details report (COURSE sheet).
-- One row per course section (class) + programme. A class mapped to several programmes is listed once per programme.
-- Programme comes from the class's programme batch sections, else from the programmes of the students added to the class
-- (custom classes), else from the class's term, else from curriculum mapping of the course.
-- Academic periods are coded as YYYYSS = <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510.
--   Mandatory / Optional  = core basket (or all-courses-mandatory basket) in the programme's curriculum -> Compulsory, else Optional
--   Credit hours          = term course credits, else term / default course version credits
--   Contact hours         = predefined: 15 * credit hours
--   Lab hours             = credits of the Lab / Practical components of the course version
--   Method of instruction = from the class's lessons: all online -> Online, none online -> In-Class, mixed -> Blended
--   Grading type          = audit basket in the programme's curriculum -> Pass/Fail, else Graded
--   Evaluation score      = average submitted course feedback (single-select answers), rescaled to 0-5
--   Skills description    = course description
-- Columns marked "Custom field - New development" have no source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    p.programme_name                                                    AS `Program Name`,
    COALESCE(NULLIF(TRIM(tc.course_code), ''), NULLIF(TRIM(tcv.course_code), ''),
             NULLIF(TRIM(dcv.course_code), ''), co.course_code)         AS `Course Code`,
    COALESCE(NULLIF(TRIM(cl.reference_id), ''), CAST(cl.id AS CHAR))    AS `Course Reference Number`,   -- section reference id, else class id
    t.acad_year_start * 100 + t.sequence * 10                           AS `Academic Period`,
    COALESCE(NULLIF(TRIM(tc.course_name), ''), NULLIF(TRIM(tcv.course_name), ''),
             NULLIF(TRIM(dcv.course_name), ''), co.course_name)         AS `Course Name`,   -- term snapshot, else term / default course version
    LEFT(COALESCE(NULLIF(TRIM(tc.description), ''), NULLIF(TRIM(tcv.description), ''),
                  NULLIF(TRIM(dcv.description), ''), NULLIF(TRIM(co.description), '')), 500) AS `Course Description`,
    pt.name                                                             AS `Course Level`,              -- programme type, e.g. Undergraduate / Post-Graduate
    CASE WHEN cur.is_non_credit = 1 OR IFNULL(COALESCE(tc.course_credits, tcv.course_credits, dcv.course_credits, co.course_credits), 0) = 0
         THEN 'Non-Credit' ELSE 'Credit' END                            AS `Course Type`,
    CASE WHEN cur.is_core = 1 THEN 'Compulsory' ELSE 'Optional' END     AS `Mandatory or Optional Indicator`,
    IFNULL(COALESCE(tc.course_credits, tcv.course_credits, dcv.course_credits, co.course_credits), 0)      AS `Credit Hours`,
    IFNULL(COALESCE(tc.course_credits, tcv.course_credits, dcv.course_credits, co.course_credits), 0) * 15 AS `Contact Hours`,
    IFNULL(cmp.lab_credits, 0)                                          AS `Lab Hours Required`,
    CASE WHEN les.lessons IS NULL OR les.lessons = 0 THEN NULL
         WHEN les.online_lessons = les.lessons THEN 'Online'
         WHEN les.online_lessons = 0 THEN 'In-Class'
         ELSE 'Blended' END                                             AS `Method of Instruction`,
    CASE WHEN cur.is_audit = 1 THEN 'Pass/Fail' ELSE 'Graded' END       AS `Grading Type`,
    IFNULL(fac.faculty_count, 0)                                        AS `Number of Faculty Members`,
    NULL                                                                AS `Co-Developed Flag`,         -- Custom field - New development (term course)
    NULL                                                                AS `Co-Developed Percentage`,   -- Custom field - New development (term course)
    NULL                                                                AS `Co-Delivered Flag`,         -- Custom field - New development (term course)
    NULL                                                                AS `Co-Delivered Percentage`,   -- Custom field - New development (term course)
    NULL                                                                AS `Number of Industry Led Sessions`, -- Custom field - New development (term course)
    ev.eval_score                                                       AS `Course Evaluation Score`,
    IFNULL(ev.eval_students, 0)                                         AS `Course Evaluation Student Count`,
    LEFT(COALESCE(NULLIF(TRIM(tc.description), ''), NULLIF(TRIM(tcv.description), ''),
                  NULLIF(TRIM(dcv.description), ''), NULLIF(TRIM(co.description), '')), 500) AS `Skills Description`,
    NULL                                                                AS `EMS Flag`                   -- Custom field - New development (course)
FROM class cl
JOIN term t                                  ON t.id = cl.term_id
LEFT JOIN course co                          ON co.course_id = cl.course_id
LEFT JOIN term_course tc                     ON tc.term_id = cl.term_id AND tc.course_id = cl.course_id
LEFT JOIN course_version tcv                 ON tcv.id = tc.course_version_id
LEFT JOIN course_version dcv                 ON dcv.course_id = cl.course_id AND dcv.is_default = 1
LEFT JOIN (
    -- programmes of a class: mapped programme batch sections, else programmes of the students added to the class
    SELECT class_id, programme_id
    FROM class_programme_batch_sections
    WHERE programme_id IS NOT NULL
    UNION
    SELECT cs.class_id, sp.programme_id
    FROM class_student cs
    JOIN student_profile sp ON sp.ukid = cs.ukid
    WHERE sp.programme_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM class_programme_batch_sections b
                      WHERE b.class_id = cs.class_id AND b.programme_id IS NOT NULL)
) cps ON cps.class_id = cl.id
LEFT JOIN (
    -- fallback: programmes whose curriculum maps the course
    SELECT DISTINCT ccc.course_id, cu.programme_id
    FROM curriculum_course ccc
    JOIN curriculum_cluster_set ccs ON ccs.id = ccc.curriculum_cluster_set_id
    JOIN curriculum_cluster cc      ON cc.id  = ccs.curriculum_cluster_id
    JOIN curriculum cu              ON cu.id  = cc.curriculum_id
    WHERE ccc.is_deleted = 0
      AND cu.programme_id IS NOT NULL
) cup ON cup.course_id = cl.course_id AND COALESCE(cps.programme_id, cl.programme_id, t.programme_id) IS NULL
LEFT JOIN programme p                        ON p.programme_id = COALESCE(cps.programme_id, cl.programme_id, t.programme_id, cup.programme_id)
LEFT JOIN programme_types pt                 ON pt.id = p.programme_type_id
LEFT JOIN (
    -- core / audit / non-credit from the programme's curriculum basket (registration type) of the course
    SELECT cu.programme_id, ccc.course_id,
           MAX(crt.registration_type = 'CORE' OR IFNULL(crt.all_courses_mandatory, 0) = 1) AS is_core,
           MAX(crt.registration_type = 'AUDIT')                                           AS is_audit,
           MIN(crt.registration_type IN ('ZERO_CREDIT', 'AUDIT'))                         AS is_non_credit
    FROM curriculum_course ccc
    JOIN curriculum_cluster_set ccs       ON ccs.id = ccc.curriculum_cluster_set_id AND ccs.is_deleted = 0
    JOIN curriculum_cluster cc            ON cc.id  = ccs.curriculum_cluster_id
    JOIN curriculum cu                    ON cu.id  = cc.curriculum_id
    LEFT JOIN course_registration_type crt ON crt.id = ccs.course_registration_type_id
    WHERE ccc.is_deleted = 0
    GROUP BY cu.programme_id, ccc.course_id
) cur ON cur.programme_id = p.programme_id AND cur.course_id = cl.course_id
LEFT JOIN (
    -- lab credits of the course version components
    SELECT ccp.course_version_id,
           SUM(CASE WHEN ccp.type IN ('LAB', 'PRACTICAL') OR cct.name IN ('Lab', 'Practical')
                    THEN IFNULL(ccp.course_credits, 0) ELSE 0 END)                       AS lab_credits
    FROM course_component ccp
    LEFT JOIN course_component_type cct ON cct.id = ccp.course_component_type_id
    GROUP BY ccp.course_version_id
) cmp ON cmp.course_version_id = COALESCE(tcv.id, dcv.id)
LEFT JOIN (
    -- scheduled lessons of the class and their online share
    SELECT class_id,
           COUNT(*)                                                    AS lessons,
           SUM(IFNULL(online, 0) = 1)                                  AS online_lessons
    FROM lesson
    WHERE IFNULL(is_cancelled, 0) = 0
    GROUP BY class_id
) les ON les.class_id = cl.id
LEFT JOIN (
    -- teaching faculty of the class (substitutes excluded)
    SELECT class_id, COUNT(DISTINCT faculty_id) AS faculty_count
    FROM class_faculty
    WHERE IFNULL(is_substitute, 0) = 0
    GROUP BY class_id
) fac ON fac.class_id = cl.id
LEFT JOIN (
    -- course feedback: submitted single-select answers, each rescaled to 0-5 by the question's top option score
    SELECT fcft.class_id,
           ROUND(AVG(o.option_score / qm.max_score * 5), 2)            AS eval_score,
           COUNT(DISTINCT fsts.student_session_id)                     AS eval_students
    FROM feedback_course_faculty_template fcft
    JOIN feedback_student_template_status fsts ON fsts.feedback_course_faculty_template_id = fcft.id AND fsts.submitted = 1
    JOIN feedback_student_response fsr         ON fsr.session_student_template_status_id = fsts.id
    JOIN feedback_template_section_question q  ON q.id = fsr.question_id AND q.question_type = 'SINGLE_SELECT'
    JOIN feedback_template_question_option o   ON o.id = fsr.option_id
    JOIN (SELECT feedback_question_id, MAX(option_score) AS max_score
          FROM feedback_template_question_option
          GROUP BY feedback_question_id
          HAVING MAX(option_score) > 0) qm     ON qm.feedback_question_id = o.feedback_question_id
    GROUP BY fcft.class_id
) ev ON ev.class_id = cl.id
ORDER BY `Academic Period` DESC, `Program Name`, `Course Code`, `Course Reference Number`;
