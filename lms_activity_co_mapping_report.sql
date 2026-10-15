/*
  LMS Activity & CO Mapping Report (term-wise, subject-wise)
  Lists every Quiz, Assignment and Activity per class with creator, mode and CO-mapped status.

  Mode
    LMS                         -> created in LMS as an assignment / activity / quiz
    Offline/Direct Component    -> class_assessment added directly in the gradebook
                                   (not backed by any assignment, quiz or discussion)

  CO Mapped = Yes when at least one active CO mapping exists:
    Assignment / Activity -> obe_assignment_course_outcomes   (or on its gradebook assessment)
    Quiz                  -> obe_quiz_course_outcomes per question (or on its gradebook assessment)
    Direct Component      -> obe_class_assessment_course_outcomes

  Notes
    - Drafts and deleted items are excluded.
    - Direct components have no creator column, so "Created By" shows the class faculty.
    - All timestamps converted from UTC to IST.
    - Filter on term: uncomment the WHERE at the bottom.
*/
SELECT
    ROW_NUMBER() OVER (ORDER BY x.term_name, x.subject, x.created_ts, x.activity_name) AS `S. No.`,
    x.term_name                                                             AS `Term`,
    x.activity_type                                                         AS `Activity Type`,
    x.activity_name                                                         AS `Activity Name`,
    DATE_FORMAT(CONVERT_TZ(x.created_ts, '+00:00', '+05:30'), '%d-%b-%Y %h:%i %p') AS `Creation Date & Time`,
    DATE_FORMAT(CONVERT_TZ(x.start_ts,   '+00:00', '+05:30'), '%d-%b-%Y %h:%i %p') AS `Activity Start Date & Time`,
    DATE_FORMAT(CONVERT_TZ(x.end_ts,     '+00:00', '+05:30'), '%d-%b-%Y %h:%i %p') AS `Activity End Date & Time`,
    x.subject                                                               AS `Subject`,
    x.course_code                                                           AS `Course Code`,
    x.created_by                                                            AS `Created By`,
    x.mode                                                                  AS `Mode`,
    IF(x.co_count > 0, 'Yes', 'No')                                         AS `CO Mapped`
FROM (
    /* ---------- Assignments & Activities (LMS) ---------- */
    SELECT
        cl.term_id,
        t.name                                                   AS term_name,
        IF(a.source_type = 'ACTIVITY', 'Activity', 'Assignment') AS activity_type,
        a.name                                                   AS activity_name,
        a.created_timestamp                                      AS created_ts,
        COALESCE(a.start_date, a.publish_datetime)               AS start_ts,
        a.due_date                                               AS end_ts,
        COALESCE(c.course_name, tc.course_name)                  AS subject,
        COALESCE(c.course_code, tc.course_code)                  AS course_code,
        TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''), NULLIF(TRIM(ua.m_name), ''), NULLIF(TRIM(ua.l_name), '')))    AS created_by,
        'LMS'                                                    AS mode,
        (SELECT COUNT(*) FROM obe_assignment_course_outcomes o
          WHERE o.assignment_id = a.id AND o.is_deleted = 0)
      + (SELECT COUNT(*) FROM obe_class_assessment_course_outcomes o
          WHERE o.assessment_id = a.assessment_id AND o.is_deleted = 0) AS co_count
    FROM assignment a
    JOIN class cl            ON cl.id = a.class_id
    JOIN term t              ON t.id = cl.term_id
    LEFT JOIN course c       ON c.course_id = cl.course_id
    LEFT JOIN term_course tc ON tc.term_id = cl.term_id AND tc.course_id = cl.course_id
    LEFT JOIN user_attributes ua ON ua.ukid = a.creator_ukid
    WHERE a.is_deleted = 0
      AND a.is_draft = 0

    UNION ALL

    /* ---------- Quizzes (LMS) ---------- */
    SELECT
        cl.term_id,
        t.name,
        'Quiz',
        q.title,
        q.created_timestamp,
        COALESCE(q.quiz_start_time, q.publish_datetime),
        COALESCE(q.quiz_end_time, q.deadline_datetime),
        COALESCE(c.course_name, tc.course_name),
        COALESCE(c.course_code, tc.course_code),
        TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''), NULLIF(TRIM(ua.m_name), ''), NULLIF(TRIM(ua.l_name), ''))),
        'LMS',
        (SELECT COUNT(*) FROM obe_quiz_course_outcomes o
           JOIN classroom_quiz_question qq ON qq.id = o.classroom_quiz_question_id
          WHERE qq.quiz_id = q.id AND o.is_deleted = 0)
      + (SELECT COUNT(*) FROM obe_class_assessment_course_outcomes o
          WHERE o.assessment_id = q.assessment_id AND o.is_deleted = 0)
    FROM classroom_quiz q
    JOIN class cl            ON cl.id = q.class_id
    JOIN term t              ON t.id = cl.term_id
    LEFT JOIN course c       ON c.course_id = cl.course_id
    LEFT JOIN term_course tc ON tc.term_id = cl.term_id AND tc.course_id = cl.course_id
    LEFT JOIN user_attributes ua ON ua.ukid = q.creator_ukid
    WHERE q.is_deleted = 0
      AND q.is_draft = 0
      AND q.parent_classroom_quiz_id IS NULL      -- skip group-quiz children

    UNION ALL

    /* ---------- Offline / Direct Components (gradebook) ---------- */
    SELECT
        cl.term_id,
        t.name,
        'Direct Component',
        ca.name,
        ca.created_timestamp,
        NULL,
        NULL,
        COALESCE(c.course_name, tc.course_name),
        COALESCE(c.course_code, tc.course_code),
        fac.faculty_names,
        'Offline/Direct Component',
        (SELECT COUNT(*) FROM obe_class_assessment_course_outcomes o
          WHERE o.assessment_id = ca.id AND o.is_deleted = 0)
    FROM class_assessment ca
    JOIN class cl            ON cl.id = ca.class_id
    JOIN term t              ON t.id = cl.term_id
    LEFT JOIN course c       ON c.course_id = cl.course_id
    LEFT JOIN term_course tc ON tc.term_id = cl.term_id AND tc.course_id = cl.course_id
    LEFT JOIN (
        SELECT cf.class_id,
               GROUP_CONCAT(DISTINCT TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''), NULLIF(TRIM(ua.m_name), ''), NULLIF(TRIM(ua.l_name), ''))) SEPARATOR ', ') AS faculty_names
        FROM class_faculty cf
        JOIN user_attributes ua ON ua.ukid = cf.faculty_id
        WHERE cf.is_substitute = 0
        GROUP BY cf.class_id
    ) fac ON fac.class_id = ca.class_id
    WHERE NOT EXISTS (SELECT 1 FROM assignment a          WHERE a.assessment_id = ca.id)
      AND NOT EXISTS (SELECT 1 FROM classroom_quiz q      WHERE q.assessment_id = ca.id)
      AND NOT EXISTS (SELECT 1 FROM classroom_discussion d WHERE d.assessment_id = ca.id)
) x
-- WHERE x.term_id = 35
ORDER BY `S. No.`;
