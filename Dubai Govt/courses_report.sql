-- Courses report (CHEDS/KHDA format).
-- One row per course section (class) + programme. A class mapped to several programmes is listed once per programme.
-- Programme comes from the class's programme batch sections, else from the programmes of the students added to the class
-- (custom classes), else from the class's term, else from curriculum mapping of the course.
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (CHEDS Semester Code list)
--   Course credit hours   = term course credits, else term / default course version credits
--   Course contact hours  = learning hours of the course version's components, else scheduled (non-cancelled) lesson hours of the class
--   Course lab            = credits of the Lab / Practical components of the course version
--   Course mode           = from the class's lessons: all online -> ON, none online -> IC, mixed -> BL
--   Course grade          = grade schema of the course's exam in that term: pass/fail schema (<= 2 grades) -> P, else G
--   Course eval score     = average submitted course feedback (single-select answers), rescaled to 0-5
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Course Institution Code`,   -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Course Institution Name`,
    p.programme_code                                                    AS `Course Program Code`,       -- Program code to be mapped (KHDA Dict)
    p.programme_name                                                    AS `Course Program Name`,
    t.acad_year_start * 100 + t.sequence * 10                           AS `Course Academic Period`,
    COALESCE(NULLIF(TRIM(tc.course_name), ''), NULLIF(TRIM(tcv.course_name), ''),
             NULLIF(TRIM(dcv.course_name), ''), co.course_name)         AS `Course Name`,   -- term snapshot, else term / default course version
    COALESCE(NULLIF(TRIM(tc.course_code), ''), NULLIF(TRIM(tcv.course_code), ''),
             NULLIF(TRIM(dcv.course_code), ''), co.course_code)         AS `Course code`,
    COALESCE(NULLIF(TRIM(cl.reference_id), ''), CAST(cl.id AS CHAR))    AS `Course CRN`,                -- section reference id, else class id
    LEFT(COALESCE(NULLIF(TRIM(tc.description), ''), NULLIF(TRIM(tcv.description), ''),
                  NULLIF(TRIM(dcv.description), ''), NULLIF(TRIM(co.description), ''),
                  NULLIF(TRIM(COALESCE(tcv.objectives, dcv.objectives, co.objectives)), '')), 4000) AS `Course desc`,
    pt.name                                                             AS `Course Degree`,             -- Degree code to be mapped (KHDA Dict, e.g. BA)
    CASE WHEN cur.is_non_credit = 1
           OR IFNULL(COALESCE(tc.course_credits, tcv.course_credits, dcv.course_credits, co.course_credits), 0) = 0
         THEN 'NC' ELSE 'CR' END                                        AS `Course credit`,
    CASE WHEN cur.is_core = 1 THEN 'M'
         WHEN cur.course_id IS NOT NULL THEN 'E'                         -- To Be Checked: elective value code ('E' / 'O')
         WHEN COALESCE(tcv.course_type, dcv.course_type, co.course_type) = 'elective' THEN 'E'
         ELSE 'M' END                                                   AS `Course mandatory`,
    COALESCE(tc.course_credits, tcv.course_credits, dcv.course_credits, co.course_credits) AS `Course credit hours`,
    ROUND(COALESCE(NULLIF(cmp.contact_hours, 0), les.lesson_hours))     AS `Course contact hours`,
    IFNULL(cmp.lab_credits, 0)                                          AS `Course lab`,
    CASE WHEN les.lessons IS NULL OR les.lessons = 0 THEN NULL
         WHEN les.online_lessons = les.lessons THEN 'ON'
         WHEN les.online_lessons = 0 THEN 'IC'                           -- To Be Checked: in-class value code
         ELSE 'BL' END                                                  AS `Course mode`,
    gr.grade_type                                                       AS `Course grade`,
    IFNULL(fac.faculty_count, 0)                                        AS `Course faculty member`,
    NULL                                                                AS `Course CoDev`,              -- Enhancement Required (Y/N)
    NULL                                                                AS `Course CoDev Percent`,      -- Enhancement Required (0-100, mandatory when CoDev = Y)
    NULL                                                                AS `Course CoDeliver`,          -- Enhancement Required (Y/N)
    NULL                                                                AS `Course CoDeliver percent`,  -- Enhancement Required (0-100, mandatory when CoDeliver = Y)
    ev.eval_score                                                       AS `Course eval score`,
    COALESCE(stp.students, st.students, 0)                              AS `Student Numbers`,
    NULL                                                                AS `Course EMB Tec`,            -- Enhancement Required
    NULL                                                                AS `Course CoSessions`,         -- Enhancement Required (mandatory when CoDeliver = Y)
    DATE_FORMAT(GREATEST(cl.modified_timestamp, COALESCE(tc.modified_timestamp, cl.modified_timestamp)), '%Y-%m-%d') AS `Last Updated`
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
LEFT JOIN college c                          ON c.college_id = COALESCE(p.college_id, t.college_id)
LEFT JOIN (
    -- core / elective / non-credit from the programme's curriculum basket (registration type) of the course
    SELECT cu.programme_id, ccc.course_id,
           MAX(crt.registration_type = 'CORE' OR IFNULL(crt.all_courses_mandatory, 0) = 1) AS is_core,
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
    -- course version components: total learning (contact) hours and lab credits
    SELECT ccp.course_version_id,
           SUM(IFNULL(ccp.learning_hours, 0))                                            AS contact_hours,
           SUM(CASE WHEN ccp.type IN ('LAB', 'PRACTICAL') OR cct.name IN ('Lab', 'Practical')
                    THEN IFNULL(ccp.course_credits, 0) ELSE 0 END)                       AS lab_credits
    FROM course_component ccp
    LEFT JOIN course_component_type cct ON cct.id = ccp.course_component_type_id
    GROUP BY ccp.course_version_id
) cmp ON cmp.course_version_id = COALESCE(tcv.id, dcv.id)
LEFT JOIN (
    -- scheduled lessons of the class: hours and online share
    SELECT class_id,
           COUNT(*)                                                    AS lessons,
           SUM(IFNULL(online, 0) = 1)                                  AS online_lessons,
           SUM(GREATEST(TIMESTAMPDIFF(MINUTE, start, end), 0)) / 60    AS lesson_hours
    FROM lesson
    WHERE IFNULL(is_cancelled, 0) = 0
    GROUP BY class_id
) les ON les.class_id = cl.id
LEFT JOIN (
    -- grade schema of the course's exam in the term: pass/fail (<= 2 grades) -> P, else G
    SELECT ee.term_id, ecs.course_id,
           CASE WHEN MAX(gsc.grades) <= 2 THEN 'P' ELSE 'G' END        AS grade_type
    FROM ems_examination_course_schema ecs
    JOIN ems_examination ee               ON ee.id = ecs.examination_id
    JOIN (SELECT grade_schema_id, COUNT(DISTINCT grade) AS grades
          FROM grade_schema_composition
          GROUP BY grade_schema_id) gsc   ON gsc.grade_schema_id = ecs.grade_schema_id
    GROUP BY ee.term_id, ecs.course_id
) gr ON gr.term_id = cl.term_id AND gr.course_id = cl.course_id
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
           ROUND(AVG(o.option_score / qm.max_score * 5), 2)            AS eval_score
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
LEFT JOIN (
    -- students of the class from this programme
    SELECT cs.class_id, sp.programme_id, COUNT(DISTINCT cs.ukid) AS students
    FROM class_student cs
    JOIN student_profile sp ON sp.ukid = cs.ukid
    GROUP BY cs.class_id, sp.programme_id
) stp ON stp.class_id = cl.id AND stp.programme_id = p.programme_id
LEFT JOIN (
    -- all students of the class (fallback when student programmes do not match)
    SELECT class_id, COUNT(DISTINCT ukid) AS students
    FROM class_student
    GROUP BY class_id
) st ON st.class_id = cl.id
ORDER BY `Course Academic Period` DESC, `Course Program Code`, `Course code`, `Course CRN`;
