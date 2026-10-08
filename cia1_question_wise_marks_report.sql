-- Module: Examination — CIA 1 Question-wise Marks Report (SKASC, collpoll_skasc)
-- Marks each student scored against each question of the CIA 1 paper, course-wise.
-- Not available in the front end; run from the backend.
--
-- How the data links up:
--   ems_examination_schema_composition (exam_type_label = 'CIA 1')   -> the assessment name
--     -> ems_examination_schema_component / component_type           -> Internals / Externals
--   ems_assessment.exam_schema_composition_id                         -> CIA 1 paper per term_course
--     -> ems_assessment_question_paper (deleted = 0)
--     -> ems_assessment_answer_sheet (one per student)
--     -> questionnaire_response (entity_name = 'EXAM_ANSWER_SHEET', entity_id = answer sheet id)
--        -> questionnaire_id = the set the student actually wrote
--     -> questionnaire_question / questionnaire_question_response     -> question-level marks
--   ems_examination_student_marks (composition + term_course + ukid)  -> final CIA 1 marks
--
-- Question structure (why marks are rolled up to the top-level question):
--   * Question numbers restart per section ("1" in Section A, B and C), so a question is
--     identified as Section + number, e.g. "Section B - Q3".
--   * ALTERNATE (either/or) questions: the parent carries maximum_marks; the options (3.1 / 3.2)
--     carry maximum_marks = 0 and normally hold the marks. A few sheets have the marks on the
--     parent instead. Rule: use the options' marks if any were recorded, else the parent's.
--   * SUB_QUESTION parents: same rule — the parts are summed into the parent.
--   * `Option Attempted` names the option that scored > 0 (blank when the student scored 0).
--
-- Scope / caveats:
--   * Only CIA 1 papers conducted through EMS (online/answer-sheet based) have question-level
--     marks. Courses whose CIA 1 marks were entered directly have no answer sheet and do not
--     appear here.
--   * `CIA 1 Marks (Final)` comes from ems_examination_student_marks; it is blank where the
--     marks haven't been pushed to the CIA 1 composition yet.
--   * Every question of the student's set is listed, including ones the student didn't answer
--     (`Marks Scored` blank).
--   * Students not yet evaluated show blank marks; filter `Answer Sheet Status` = 'COMPLETED'
--     to keep evaluated sheets only.
--   * Data check (Oct 2026): for ~98.4% of evaluated sheets the question marks add up exactly
--     to the answer-sheet total / CIA 1 marks. For the remaining ~1.6% (~645 sheets) the sheet
--     total was edited after question-level marking, so the question marks don't add up to it.
--     Query 2 flags these in `Totals Check`.

-- ===========================================================================
-- 1) Long format — one row per student x course x question
-- ===========================================================================
SELECT
    t.name                                              AS `Term`,
    COALESCE(cv.course_code, crs.course_code)          AS `Course Code`,
    COALESCE(cv.course_name, crs.course_name)          AS `Course Name`,
    ct.name                                             AS `Component`,
    c.exam_type_label                                   AS `Assessment`,
    DATE(CONVERT_TZ(a.start_datetime, '+00:00', '+05:30')) AS `Exam Date`,
    ua.registration_id                                  AS `Registration ID`,
    TRIM(CONCAT_WS(' ', ua.f_name, ua.m_name, ua.l_name)) AS `Student Name`,
    p.programme_name                                    AS `Programme`,
    s.answer_sheet_number                               AS `Answer Sheet No`,
    ps.set_label                                        AS `Set`,
    qs.title                                            AS `Section`,
    qq.sequence_label                                   AS `Question No`,
    qq.question_type                                    AS `Question Type`,
    qq.question                                         AS `Question`,
    qq.maximum_marks                                    AS `Max Marks`,
    COALESCE(ch.child_marks, pr.marks)                  AS `Marks Scored`,
    ch.option_attempted                                 AS `Option Attempted`,
    s.marks                                             AS `Answer Sheet Total`,
    m.marks                                             AS `CIA 1 Marks (Final)`,
    c.maximum_marks                                     AS `CIA 1 Max Marks`,
    CASE m.is_attended WHEN 1 THEN 'Present' WHEN 0 THEN 'Absent' END AS `Attendance`,
    s.status                                            AS `Answer Sheet Status`,
    TRIM(CONCAT_WS(' ', ev.f_name, ev.l_name))          AS `Evaluator`
FROM ems_examination_schema_composition c
JOIN ems_examination_schema_component sc ON sc.id = c.schema_component_id
JOIN ems_examination_component_type   ct ON ct.id = sc.component_type_id
JOIN ems_assessment a                    ON a.exam_schema_composition_id = c.id
JOIN term_course tc                      ON tc.id = a.term_course_id
LEFT JOIN term t                         ON t.id = tc.term_id
LEFT JOIN course_version cv               ON cv.id = tc.course_version_id
LEFT JOIN course crs                     ON crs.course_id = tc.course_id
JOIN ems_assessment_question_paper qp    ON qp.assessment_id = a.id AND qp.deleted = 0
JOIN ems_assessment_answer_sheet s       ON s.question_paper_id = qp.id
JOIN user_attributes ua                  ON ua.ukid = s.examinee_ukid
LEFT JOIN student_profile sp             ON sp.ukid = s.examinee_ukid
LEFT JOIN programme p                    ON p.programme_id = sp.programme_id
LEFT JOIN user_attributes ev             ON ev.ukid = s.evaluator_ukid
-- the set this student actually wrote
JOIN questionnaire_response qr           ON qr.entity_id = s.id
                                        AND qr.entity_name = 'EXAM_ANSWER_SHEET'
                                        AND qr.student_ukid = s.examinee_ukid
LEFT JOIN ems_assessment_question_paper_set ps
                                         ON ps.question_paper_id = qp.id
                                        AND ps.questionnaire_id = qr.questionnaire_id
-- top-level questions only; options / parts are rolled up below
JOIN questionnaire_question qq           ON qq.questionnaire_id = qr.questionnaire_id
                                        AND qq.parent_question_id IS NULL
                                        AND qq.deleted_at IS NULL
LEFT JOIN questionnaire_section qs       ON qs.id = qq.section_id
-- marks recorded directly on the question
LEFT JOIN questionnaire_question_response pr
                                         ON pr.questionnaire_response_id = qr.id
                                        AND pr.question_id = qq.id
                                        AND pr.is_deleted = 0
-- marks recorded on the question's options (ALTERNATE) / parts (SUB_QUESTION)
LEFT JOIN (
    SELECT r.questionnaire_response_id,
           cq.parent_question_id,
           SUM(r.marks) AS child_marks,
           GROUP_CONCAT(CASE WHEN r.marks > 0 THEN cq.sequence_label END
                        ORDER BY cq.sequence_label SEPARATOR ', ') AS option_attempted
    FROM questionnaire_question_response r
    JOIN questionnaire_question cq ON cq.id = r.question_id
                                  AND cq.parent_question_id IS NOT NULL
                                  AND cq.deleted_at IS NULL
    WHERE r.is_deleted = 0
    GROUP BY r.questionnaire_response_id, cq.parent_question_id
) ch                                     ON ch.questionnaire_response_id = qr.id
                                        AND ch.parent_question_id = qq.id
-- final CIA 1 marks for the student in this course
LEFT JOIN ems_examination_student_marks m
                                         ON m.exam_schema_composition_id = c.id
                                        AND m.term_course_id = a.term_course_id
                                        AND m.student_ukid = s.examinee_ukid
WHERE c.exam_type_label = 'CIA 1'
  AND ct.name = 'Internals'
  -- AND COALESCE(cv.course_code, crs.course_code) = '<COURSE_CODE>'          -- optional: one course
  -- AND s.status = 'COMPLETED'                    -- optional: evaluated sheets only
ORDER BY `Course Code`, ua.registration_id, qs.sequence, qq.id;


-- ===========================================================================
-- 2) Wide format — one row per student x course, questions in a single column
--    e.g. "A-1: 2/2 | A-2: 1.5/2 | B-1 (1.1): 3/4 | ..."
--    (A true column-per-question pivot isn't possible in one query because every
--     course has a different paper; export query 1 and pivot in Excel if needed.)
-- ===========================================================================
SELECT
    t.name                                              AS `Term`,
    COALESCE(cv.course_code, crs.course_code)          AS `Course Code`,
    COALESCE(cv.course_name, crs.course_name)          AS `Course Name`,
    ua.registration_id                                  AS `Registration ID`,
    TRIM(CONCAT_WS(' ', ua.f_name, ua.m_name, ua.l_name)) AS `Student Name`,
    p.programme_name                                    AS `Programme`,
    s.answer_sheet_number                               AS `Answer Sheet No`,
    ps.set_label                                        AS `Set`,
    GROUP_CONCAT(
        CONCAT(UPPER(TRIM(REPLACE(COALESCE(qs.title, ''), 'Section', ''))), '-', qq.sequence_label,
               IF(ch.option_attempted IS NOT NULL, CONCAT(' (', ch.option_attempted, ')'), ''),
               ': ', COALESCE(CAST(COALESCE(ch.child_marks, pr.marks) AS DOUBLE), '-'),
               '/', CAST(qq.maximum_marks AS DOUBLE))
        ORDER BY qs.sequence, qq.id SEPARATOR ' | ')   AS `Question-wise Marks`,
    SUM(COALESCE(ch.child_marks, pr.marks, 0))          AS `Sum of Question Marks`,
    s.marks                                             AS `Answer Sheet Total`,
    m.marks                                             AS `CIA 1 Marks (Final)`,
    c.maximum_marks                                     AS `CIA 1 Max Marks`,
    IF(ABS(SUM(COALESCE(ch.child_marks, pr.marks, 0)) - IFNULL(s.marks, 0)) < 0.01,
       'Match', 'Question sum <> sheet total')          AS `Totals Check`,
    s.status                                            AS `Answer Sheet Status`
FROM ems_examination_schema_composition c
JOIN ems_examination_schema_component sc ON sc.id = c.schema_component_id
JOIN ems_examination_component_type   ct ON ct.id = sc.component_type_id
JOIN ems_assessment a                    ON a.exam_schema_composition_id = c.id
JOIN term_course tc                      ON tc.id = a.term_course_id
LEFT JOIN term t                         ON t.id = tc.term_id
LEFT JOIN course_version cv               ON cv.id = tc.course_version_id
LEFT JOIN course crs                     ON crs.course_id = tc.course_id
JOIN ems_assessment_question_paper qp    ON qp.assessment_id = a.id AND qp.deleted = 0
JOIN ems_assessment_answer_sheet s       ON s.question_paper_id = qp.id
JOIN user_attributes ua                  ON ua.ukid = s.examinee_ukid
LEFT JOIN student_profile sp             ON sp.ukid = s.examinee_ukid
LEFT JOIN programme p                    ON p.programme_id = sp.programme_id
JOIN questionnaire_response qr           ON qr.entity_id = s.id
                                        AND qr.entity_name = 'EXAM_ANSWER_SHEET'
                                        AND qr.student_ukid = s.examinee_ukid
LEFT JOIN ems_assessment_question_paper_set ps
                                         ON ps.question_paper_id = qp.id
                                        AND ps.questionnaire_id = qr.questionnaire_id
JOIN questionnaire_question qq           ON qq.questionnaire_id = qr.questionnaire_id
                                        AND qq.parent_question_id IS NULL
                                        AND qq.deleted_at IS NULL
LEFT JOIN questionnaire_section qs       ON qs.id = qq.section_id
LEFT JOIN questionnaire_question_response pr
                                         ON pr.questionnaire_response_id = qr.id
                                        AND pr.question_id = qq.id
                                        AND pr.is_deleted = 0
LEFT JOIN (
    SELECT r.questionnaire_response_id,
           cq.parent_question_id,
           SUM(r.marks) AS child_marks,
           GROUP_CONCAT(CASE WHEN r.marks > 0 THEN cq.sequence_label END
                        ORDER BY cq.sequence_label SEPARATOR ', ') AS option_attempted
    FROM questionnaire_question_response r
    JOIN questionnaire_question cq ON cq.id = r.question_id
                                  AND cq.parent_question_id IS NOT NULL
                                  AND cq.deleted_at IS NULL
    WHERE r.is_deleted = 0
    GROUP BY r.questionnaire_response_id, cq.parent_question_id
) ch                                     ON ch.questionnaire_response_id = qr.id
                                        AND ch.parent_question_id = qq.id
LEFT JOIN ems_examination_student_marks m
                                         ON m.exam_schema_composition_id = c.id
                                        AND m.term_course_id = a.term_course_id
                                        AND m.student_ukid = s.examinee_ukid
WHERE c.exam_type_label = 'CIA 1'
  AND ct.name = 'Internals'
  -- AND COALESCE(cv.course_code, crs.course_code) = '<COURSE_CODE>'
GROUP BY s.id
ORDER BY `Course Code`, ua.registration_id;
