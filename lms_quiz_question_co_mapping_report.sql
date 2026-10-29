/*
  LMS Quiz Question & CO Mapping Report (term-wise, subject-wise, question-level)
  Lists every question of every LMS quiz per class with its type, marks and CO mapping.
  Question-level companion to lms_activity_co_mapping_report.sql.

  Question sources
    Classic quiz        -> classroom_quiz_question (quiz_id)
    Questionnaire quiz  -> classroom_quiz_questionnaire -> questionnaire_question
                           (quizzes with has_questionnaire = 1 keep no rows in classroom_quiz_question)

  CO Mapped = Yes when the question has at least one active CO mapping:
    Classic quiz        -> obe_quiz_course_outcomes (is_deleted = 0)
    Questionnaire quiz  -> questionnaire_question_course_outcome
    - CO Codes / Difficulty Level list every CO mapped to the question.
    - Gradebook-level CO mapping on the quiz's assessment is NOT considered here
      (that is reported at quiz level in lms_activity_co_mapping_report.sql).

  Notes
    - Drafts and deleted quizzes are excluded; group-quiz children are skipped (questions
      live on the parent quiz). Deleted questionnaire questions (deleted_at set) are excluded.
    - Comprehension parent questions are excluded; their sub-questions are listed.
    - Question No. is numbered per quiz and question set, in creation order
      (questionnaire quizzes follow sequence_label first).
    - HTML tags in the question body are stripped and common named entities decoded;
      numeric entities (e.g. &#2694; for non-Latin scripts) are left as-is.
    - Subject / Course Code come from the term's course_version, falling back to
      the default course_version, then course, then term_course.
    - All timestamps converted from UTC to IST.
    - Filter on term: uncomment the WHERE at the bottom.
*/
SELECT
    ROW_NUMBER() OVER (ORDER BY x.term_name, x.subject, x.quiz_created_ts, x.quiz_name, x.question_set, x.question_no) AS `S. No.`,
    x.term_name                                                             AS `Term`,
    x.subject                                                               AS `Subject`,
    x.course_code                                                           AS `Course Code`,
    x.quiz_name                                                             AS `Quiz Name`,
    DATE_FORMAT(CONVERT_TZ(x.quiz_created_ts, '+00:00', '+05:30'), '%d-%b-%Y %h:%i %p') AS `Quiz Creation Date & Time`,
    DATE_FORMAT(CONVERT_TZ(x.start_ts,        '+00:00', '+05:30'), '%d-%b-%Y %h:%i %p') AS `Quiz Start Date & Time`,
    DATE_FORMAT(CONVERT_TZ(x.end_ts,          '+00:00', '+05:30'), '%d-%b-%Y %h:%i %p') AS `Quiz End Date & Time`,
    x.created_by                                                            AS `Created By`,
    x.section_name                                                          AS `Section`,
    x.question_set                                                          AS `Question Set`,
    x.question_no                                                           AS `Question No.`,
    x.question_text                                                         AS `Question`,
    x.question_type                                                         AS `Question Type`,
    x.max_marks                                                             AS `Max Marks`,
    IF(x.co_count > 0, 'Yes', 'No')                                         AS `CO Mapped`,
    x.co_codes                                                              AS `CO Codes`,
    x.difficulty_levels                                                     AS `Difficulty Level`
FROM (
    SELECT
        cl.term_id,
        t.name                                                   AS term_name,
        COALESCE(cv.course_name, dcv.course_name, c.course_name, tc.course_name) AS subject,
        COALESCE(cv.course_code, dcv.course_code, c.course_code, tc.course_code) AS course_code,
        q.title                                                  AS quiz_name,
        q.created_timestamp                                      AS quiz_created_ts,
        COALESCE(q.quiz_start_time, q.publish_datetime)          AS start_ts,
        COALESCE(q.quiz_end_time, q.deadline_datetime)           AS end_ts,
        TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''), NULLIF(TRIM(ua.m_name), ''), NULLIF(TRIM(ua.l_name), ''))) AS created_by,
        qs.section_name,
        qs.question_set,
        ROW_NUMBER() OVER (PARTITION BY q.id, qs.question_set ORDER BY qs.sort_label, qs.question_id) AS question_no,
        TRIM(REGEXP_REPLACE(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REGEXP_REPLACE(qs.question_body, '<[^>]*>', ' '),
                '&nbsp;', ' '), '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&#39;', ''''),
                '&ldquo;', '"'), '&rdquo;', '"'), '&lsquo;', ''''), '&rsquo;', ''''), '&amp;', '&'),
            '[[:space:]]+', ' '))                                AS question_text,
        CASE qs.question_type
            WHEN 'SINGLE_CORRECT'   THEN 'Single Correct'
            WHEN 'MULTIPLE_CORRECT' THEN 'Multiple Correct'
            WHEN 'SUBJECTIVE'       THEN 'Subjective'
            WHEN 'FILL_UP'          THEN 'Fill in the Blank'
            WHEN 'MTF'              THEN 'Match the Following'
            WHEN 'NUMERICAL'        THEN 'Numerical'
            WHEN 'PROGRAMMING'      THEN 'Programming'
            ELSE qs.question_type
        END                                                      AS question_type,
        qs.max_marks,
        qs.co_count,
        qs.co_codes,
        qs.difficulty_levels
    FROM (
        /* ---------- Classic quiz questions ---------- */
        SELECT
            qq.quiz_id,
            qq.id                                                AS question_id,
            COALESCE(NULLIF(TRIM(g.title), ''), g.name)          AS section_name,
            qq.question_set,
            NULL                                                 AS sort_label,
            COALESCE(qq.question_body, qq.math_question_body)    AS question_body,
            qq.type                                              AS question_type,
            qq.maximum_marks                                     AS max_marks,
            COALESCE(co.co_count, 0)                             AS co_count,
            co.co_codes,
            co.difficulty_levels
        FROM classroom_quiz_question qq
        LEFT JOIN classroom_quiz_group g ON g.id = qq.quiz_group_id
        LEFT JOIN (
            SELECT o.classroom_quiz_question_id,
                   COUNT(*)                                                           AS co_count,
                   GROUP_CONCAT(DISTINCT oc.code ORDER BY oc.code SEPARATOR ', ')     AS co_codes,
                   GROUP_CONCAT(DISTINCT dl.name ORDER BY dl.sequence SEPARATOR ', ') AS difficulty_levels
            FROM obe_quiz_course_outcomes o
            LEFT JOIN obe_course_outcomes oc   ON oc.id = o.obe_course_outcome_id
            LEFT JOIN obe_difficulty_levels dl ON dl.id = o.obe_difficulty_level_id
            WHERE o.is_deleted = 0
            GROUP BY o.classroom_quiz_question_id
        ) co ON co.classroom_quiz_question_id = qq.id
        WHERE COALESCE(qq.is_parent, 0) = 0                  -- skip comprehension parent containers

        UNION ALL

        /* ---------- Questionnaire quiz questions ---------- */
        SELECT
            cqq.classroom_quiz_id,
            qnq.id,
            sec.title,
            cqq.questionnaire_set,
            CAST(qnq.sequence_label AS UNSIGNED),
            qnq.question,
            qnq.question_type,
            qnq.maximum_marks,
            COALESCE(co.co_count, 0),
            co.co_codes,
            co.difficulty_levels
        FROM classroom_quiz_questionnaire cqq
        JOIN questionnaire_question qnq        ON qnq.questionnaire_id = cqq.questionnaire_id
        LEFT JOIN questionnaire_section sec    ON sec.id = qnq.section_id
        LEFT JOIN (
            SELECT o.questionnaire_question_id,
                   COUNT(*)                                                           AS co_count,
                   GROUP_CONCAT(DISTINCT oc.code ORDER BY oc.code SEPARATOR ', ')     AS co_codes,
                   GROUP_CONCAT(DISTINCT dl.name ORDER BY dl.sequence SEPARATOR ', ') AS difficulty_levels
            FROM questionnaire_question_course_outcome o
            LEFT JOIN obe_course_outcomes oc   ON oc.id = o.obe_course_outcome_id
            LEFT JOIN obe_difficulty_levels dl ON dl.id = o.obe_difficult_level_id
            GROUP BY o.questionnaire_question_id
        ) co ON co.questionnaire_question_id = qnq.id
        WHERE qnq.deleted_at IS NULL
          AND NOT EXISTS (SELECT 1 FROM questionnaire_question ch   -- skip comprehension parent containers
                           WHERE ch.parent_question_id = qnq.id AND ch.deleted_at IS NULL)
    ) qs
    JOIN classroom_quiz q    ON q.id = qs.quiz_id
    JOIN class cl            ON cl.id = q.class_id
    JOIN term t              ON t.id = cl.term_id
    LEFT JOIN course c       ON c.course_id = cl.course_id
    LEFT JOIN term_course tc ON tc.term_id = cl.term_id AND tc.course_id = cl.course_id
    LEFT JOIN course_version cv  ON cv.id = tc.course_version_id
    LEFT JOIN course_version dcv ON dcv.course_id = cl.course_id AND dcv.is_default = 1
    LEFT JOIN user_attributes ua ON ua.ukid = q.creator_ukid
    WHERE q.is_deleted = 0
      AND q.is_draft = 0
      AND q.parent_classroom_quiz_id IS NULL      -- skip group-quiz children
) x
-- WHERE x.term_id = 35
ORDER BY `S. No.`;
