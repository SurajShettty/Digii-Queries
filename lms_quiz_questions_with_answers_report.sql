/*
  LMS Quiz Questions with Correct Answers (single course + faculty)
  Lists every question of every LMS quiz for a course taught by a faculty, with all
  options and the correct answer.

  Filters (edit at the bottom): course name LIKE '%News Analysis%', faculty 'Bhavneet Singh'
    - Faculty matches either a faculty mapped to the class (class_faculty) or the quiz creator.

  Correct answer by question type
    Single / Multiple Correct -> options with is_correct = 1
    Fill in the Blank         -> answer key per blank (sub_question -> answer_key)
    Match the Following       -> "left = right" pairs (sub_question -> answer_key -> mtf_answer)
    Numerical / Subjective    -> question-level answer_key
  Question sources
    Classic quiz        -> classroom_quiz_question / classroom_quiz_option
    Questionnaire quiz  -> classroom_quiz_questionnaire -> questionnaire_question / questionnaire_question_option

  Notes
    - Drafts, deleted quizzes, group-quiz children, comprehension parents and deleted
      questionnaire questions are excluded.
    - HTML tags stripped from question, options and answers; common entities decoded.
*/
USE collpoll_iilmgg;
SET SESSION group_concat_max_len = 1000000;

SELECT
    ROW_NUMBER() OVER (ORDER BY x.term_name, x.quiz_created_ts, x.quiz_name, x.question_set, x.question_no) AS `S. No.`,
    x.term_name                                                             AS `Term`,
    x.subject                                                               AS `Subject`,
    x.course_code                                                           AS `Course Code`,
    x.class_name                                                            AS `Class`,
    x.faculty                                                               AS `Faculty`,
    x.quiz_name                                                             AS `Quiz Name`,
    DATE_FORMAT(CONVERT_TZ(x.quiz_created_ts, '+00:00', '+05:30'), '%d-%b-%Y %h:%i %p') AS `Quiz Creation Date & Time`,
    x.question_set                                                          AS `Question Set`,
    x.question_no                                                           AS `Question No.`,
    x.question_type                                                         AS `Question Type`,
    x.question_text                                                         AS `Question`,
    x.options                                                               AS `Options`,
    x.correct_answer                                                        AS `Correct Answer`,
    x.max_marks                                                             AS `Max Marks`
FROM (
    SELECT
        t.name                                                   AS term_name,
        COALESCE(cv.course_name, dcv.course_name, c.course_name, tc.course_name) AS subject,
        COALESCE(cv.course_code, dcv.course_code, c.course_code, tc.course_code) AS course_code,
        cl.batch                                                 AS class_name,
        fac.faculty,
        q.title                                                  AS quiz_name,
        q.created_timestamp                                      AS quiz_created_ts,
        qs.question_set,
        ROW_NUMBER() OVER (PARTITION BY q.id, qs.question_set ORDER BY qs.sort_label, qs.question_id) AS question_no,
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
        TRIM(REGEXP_REPLACE(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REGEXP_REPLACE(qs.question_body, '<[^>]*>', ' '),
                '&nbsp;', ' '), '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&#39;', ''''),
                '&ldquo;', '"'), '&rdquo;', '"'), '&lsquo;', ''''), '&rsquo;', ''''), '&amp;', '&'),
            '[[:space:]]+', ' '))                                AS question_text,
        TRIM(REGEXP_REPLACE(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REGEXP_REPLACE(qs.options, '<[^>]*>', ' '),
                '&nbsp;', ' '), '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&#39;', ''''),
                '&ldquo;', '"'), '&rdquo;', '"'), '&lsquo;', ''''), '&rsquo;', ''''), '&amp;', '&'),
            '[ \t]+', ' '))                                      AS options,
        TRIM(REGEXP_REPLACE(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                REGEXP_REPLACE(qs.correct_answer, '<[^>]*>', ' '),
                '&nbsp;', ' '), '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&#39;', ''''),
                '&ldquo;', '"'), '&rdquo;', '"'), '&lsquo;', ''''), '&rsquo;', ''''), '&amp;', '&'),
            '[ \t]+', ' '))                                      AS correct_answer,
        qs.max_marks
    FROM (
        /* ---------- Classic quiz questions ---------- */
        SELECT
            qq.quiz_id,
            qq.id                                                AS question_id,
            qq.question_set,
            NULL                                                 AS sort_label,
            COALESCE(qq.question_body, qq.math_question_body)    AS question_body,
            qq.type                                              AS question_type,
            qq.maximum_marks                                     AS max_marks,
            opt.options,
            CASE
                WHEN qq.type IN ('SINGLE_CORRECT', 'MULTIPLE_CORRECT') THEN opt.correct_options
                WHEN qq.type IN ('FILL_UP', 'MTF')                     THEN sq.answers
                ELSE COALESCE(qq.answer_key, qq.math_answer_key)
            END                                                  AS correct_answer
        FROM classroom_quiz_question qq
        LEFT JOIN (
            SELECT o.question_id,
                   GROUP_CONCAT(CONCAT(CHAR(64 + o.rn), ') ', o.body) ORDER BY o.rn SEPARATOR '\n') AS options,
                   GROUP_CONCAT(CASE WHEN o.is_correct = 1 THEN CONCAT(CHAR(64 + o.rn), ') ', o.body) END
                                ORDER BY o.rn SEPARATOR '\n')                                   AS correct_options
            FROM (
                SELECT question_id, is_correct,
                       COALESCE(NULLIF(option_body, ''), NULLIF(math_option_body, ''), text, option_value) AS body,
                       ROW_NUMBER() OVER (PARTITION BY question_id ORDER BY id) AS rn
                FROM classroom_quiz_option
            ) o
            GROUP BY o.question_id
        ) opt ON opt.question_id = qq.id
        LEFT JOIN (
            SELECT s.question_id,
                   GROUP_CONCAT(
                       CASE WHEN s.mtf_question IS NOT NULL
                            THEN CONCAT(s.mtf_question, ' = ', COALESCE(ma.mtf_answer, ''))
                            ELSE CONCAT('Blank ', COALESCE(s.blank_number, ''), ': ', COALESCE(ak.answer_key, ''))
                       END
                       ORDER BY s.blank_number, s.id SEPARATOR '\n')          AS answers
            FROM classroom_quiz_sub_question s
            LEFT JOIN classroom_quiz_answer_key ak  ON ak.sub_question_id = s.id
            LEFT JOIN classroom_quiz_mtf_answer ma  ON ma.id = ak.mtf_answer_id
            GROUP BY s.question_id
        ) sq ON sq.question_id = qq.id
        WHERE COALESCE(qq.is_parent, 0) = 0                  -- skip comprehension parent containers

        UNION ALL

        /* ---------- Questionnaire quiz questions ---------- */
        SELECT
            cqq.classroom_quiz_id,
            qnq.id,
            cqq.questionnaire_set,
            CAST(qnq.sequence_label AS UNSIGNED),
            qnq.question,
            qnq.question_type,
            qnq.maximum_marks,
            opt.options,
            CASE
                WHEN qnq.question_type IN ('SINGLE_CORRECT', 'MULTIPLE_CORRECT') THEN opt.correct_options
                WHEN qnq.question_type IN ('FILL_UP', 'MTF')                     THEN sq.answers
                ELSE qnq.answer_key
            END
        FROM classroom_quiz_questionnaire cqq
        JOIN questionnaire_question qnq ON qnq.questionnaire_id = cqq.questionnaire_id
        LEFT JOIN (
            SELECT o.questionnaire_question_id,
                   GROUP_CONCAT(CONCAT(CHAR(64 + o.rn), ') ', o.body) ORDER BY o.rn SEPARATOR '\n') AS options,
                   GROUP_CONCAT(CASE WHEN o.is_correct = 1 THEN CONCAT(CHAR(64 + o.rn), ') ', o.body) END
                                ORDER BY o.rn SEPARATOR '\n')                                   AS correct_options
            FROM (
                SELECT questionnaire_question_id, is_correct, `option` AS body,
                       ROW_NUMBER() OVER (PARTITION BY questionnaire_question_id ORDER BY id) AS rn
                FROM questionnaire_question_option
            ) o
            GROUP BY o.questionnaire_question_id
        ) opt ON opt.questionnaire_question_id = qnq.id
        LEFT JOIN (
            SELECT s.questionnaire_question_id,
                   GROUP_CONCAT(
                       CASE WHEN s.mtf_question IS NOT NULL
                            THEN CONCAT(s.mtf_question, ' = ', COALESCE(ma.mtf_answer, ''))
                            ELSE CONCAT('Blank ', COALESCE(s.blank_number, ''), ': ', COALESCE(ak.fillup_answer_key, ''))
                       END
                       ORDER BY s.blank_number, s.id SEPARATOR '\n')          AS answers
            FROM questionnaire_question_sub_question s
            LEFT JOIN questionnaire_question_answer_key ak ON ak.questionnaire_question_sub_question_id = s.id
            LEFT JOIN questionnaire_question_mtf_answer ma ON ma.id = ak.mtf_answer_id
            GROUP BY s.questionnaire_question_id
        ) sq ON sq.questionnaire_question_id = qnq.id
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
    LEFT JOIN (
        SELECT cf.class_id,
               GROUP_CONCAT(DISTINCT TRIM(CONCAT_WS(' ', NULLIF(TRIM(u.f_name), ''), NULLIF(TRIM(u.m_name), ''), NULLIF(TRIM(u.l_name), '')))
                            SEPARATOR ', ') AS faculty
        FROM class_faculty cf
        JOIN user_attributes u ON u.ukid = cf.faculty_id
        GROUP BY cf.class_id
    ) fac ON fac.class_id = cl.id
    WHERE q.is_deleted = 0
      AND q.is_draft = 0
      AND q.parent_classroom_quiz_id IS NULL      -- skip group-quiz children
      AND COALESCE(cv.course_name, dcv.course_name, c.course_name, tc.course_name) LIKE '%News Analysis%'
      AND (   fac.faculty LIKE '%Bhavneet%Singh%'
           OR CONCAT_WS(' ', ua.f_name, ua.m_name, ua.l_name) LIKE '%Bhavneet%Singh%')
) x
ORDER BY `S. No.`;
