SELECT 
    cs.class_id,
    cs.ukid AS student_ukid,
    CONCAT(ua.f_name, ' ', ua.l_name) AS student_name,
    ua.registration_id,
    a.email email_id,
    eas.answer_sheet_number,
    esch.name AS exam_name,
    t.name AS term_name,
    tc.id AS term_course_id,
    crs.course_code,
    cv.course_name,
    ema.id AS assessment_id,
    ema.start_datetime AS assessment_start,
    eaqp.id AS question_paper_id,
    eaqps.set_label,
    q.id AS questionnaire_id,
    qs.title AS section_title,
    qq.id AS question_id,
    qq.sequence_label AS question_number,
    qq.question,
    qq.question_type,
    qq.maximum_marks,
    co_map.co_codes AS CO,
    qr.id AS response_id,
    qr.attempt_no,
    COALESCE(resp.multi_value_response,
            resp.selected_options,
            resp.content_text) AS response_display,
    resp.selected_options,
    resp.multi_value_response,
    resp.content_text,
    resp.response_marks,
    eas.status AS answer_sheet_status,
    eas.deadline,
    CONCAT(ev.f_name, ' ', ev.l_name) AS evaluator_name,
    ev.registration_id AS evaluator_reg_id,
    CASE
        WHEN ema.id IS NULL THEN 'NO_ASSESSMENT'
        WHEN qr.id IS NULL THEN 'NOT_RESPONDED'
        WHEN resp.has_response IS NULL THEN 'NO_RESPONSE_TO_QUESTION'
        ELSE 'RESPONDED'
    END AS response_status,
    pus.final_score AS confidence_score
FROM
    class_student cs
        INNER JOIN
    user_attributes ua ON ua.ukid = cs.ukid
        INNER JOIN
    authenticator a ON a.ukid = ua.ukid
        JOIN
    class cl ON cl.id = cs.class_id
        JOIN
    term_course tc ON tc.course_id = cl.course_id
        AND tc.term_id = cl.term_id
        LEFT JOIN
    term t ON t.id = tc.term_id
        LEFT JOIN
    course_version cv ON cv.id = tc.course_version_id
        LEFT JOIN
    course crs ON crs.course_id = cv.course_id
        LEFT JOIN
    ems_assessment ema ON ema.term_course_id = tc.id
        LEFT JOIN
    ems_assessment_schedule esch ON esch.id = ema.assessment_schedule_id
        LEFT JOIN
    ems_assessment_question_paper eaqp ON eaqp.assessment_id = ema.id
        -- the student's answer sheet for this paper (drives which set they took)
        LEFT JOIN
    ems_assessment_answer_sheet eas ON eas.question_paper_id = eaqp.id
        AND eas.examinee_ukid = cs.ukid
        -- evaluator who marked this answer sheet
        LEFT JOIN
    user_attributes ev ON ev.ukid = eas.evaluator_ukid
        -- the response tied to THAT answer sheet -> the one set the student actually took
        LEFT JOIN
    questionnaire_response qr ON qr.entity_id = eas.id
        AND qr.entity_name = 'EXAM_ANSWER_SHEET'
        AND qr.student_ukid = cs.ukid
        LEFT JOIN
    questionnaire q ON q.id = qr.questionnaire_id
        -- only the student's set, just for set_label
        LEFT JOIN
    ems_assessment_question_paper_set eaqps ON eaqps.question_paper_id = eaqp.id
        AND eaqps.questionnaire_id = qr.questionnaire_id
        LEFT JOIN
    questionnaire_question qq ON qq.questionnaire_id = q.id
        AND qq.deleted_at IS NULL
        LEFT JOIN
    questionnaire_section qs ON qs.id = qq.section_id
        -- course outcome(s) mapped to each question (aggregated so a multi-CO question stays one row)
        LEFT JOIN
    (SELECT 
        qco.questionnaire_question_id,
            GROUP_CONCAT(DISTINCT co.code ORDER BY co.code SEPARATOR ', ') AS co_codes
    FROM
        questionnaire_question_course_outcome qco
    JOIN obe_course_outcomes co ON co.id = qco.obe_course_outcome_id
        AND co.is_deleted = 0
    GROUP BY qco.questionnaire_question_id) co_map ON co_map.questionnaire_question_id = qq.id
        LEFT JOIN
    (SELECT 
        qqr.questionnaire_response_id,
            qqr.question_id,
            1 AS has_response,
            MAX(qqr.marks) AS response_marks,
            NULLIF(CONVERT( GROUP_CONCAT(DISTINCT qqo.`option`
                ORDER BY qqo.id
                SEPARATOR ' | ') USING UTF8MB4), '') AS selected_options,
            NULLIF(CONVERT( GROUP_CONCAT(DISTINCT qqr.content
                SEPARATOR ' | ') USING UTF8MB4), '') AS content_text,
            NULLIF(CONVERT( GROUP_CONCAT(DISTINCT CASE
                WHEN qqmvr.response_value IS NOT NULL THEN CONCAT(COALESCE(CAST(sq.blank_number AS CHAR), CAST(sq.id AS CHAR)), ': ', qqmvr.response_value)
                WHEN qqmvr.option_id IS NOT NULL THEN CONVERT( mvr_opt.`option` USING UTF8MB4)
                WHEN qqmvr.mtf_answer_id IS NOT NULL THEN CONCAT(COALESCE(sq.mtf_question, ''), ' -> ', COALESCE(mtfa.mtf_answer, ''))
            END
                ORDER BY qqmvr.sub_question_id , qqmvr.id
                SEPARATOR ' | ') USING UTF8MB4), '') AS multi_value_response
    FROM
        questionnaire_question_response qqr
    LEFT JOIN questionnaire_question_option qqo ON qqo.id = qqr.option_id
    LEFT JOIN questionnaire_question_multi_value_response qqmvr ON qqmvr.questionnaire_question_response_id = qqr.id
    LEFT JOIN questionnaire_question_option mvr_opt ON mvr_opt.id = qqmvr.option_id
    LEFT JOIN questionnaire_question_sub_question sq ON sq.id = qqmvr.sub_question_id
    LEFT JOIN questionnaire_question_mtf_answer mtfa ON mtfa.id = qqmvr.mtf_answer_id
    WHERE
        qqr.is_deleted = 0
    GROUP BY qqr.questionnaire_response_id , qqr.question_id) resp ON resp.questionnaire_response_id = qr.id
        AND resp.question_id = qq.id
        LEFT JOIN
    proctor_user_session pus ON pus.entity_id = ema.id
        AND pus.ukid = cs.ukid
WHERE

 -- crs.course_code in ('MG3994')
--     eas.answer_sheet_number = '00033422'
 esch.name = 'Global Futures Scholarship Test - June 2026'
ORDER BY cs.class_id , cs.ukid , ema.start_datetime , qq.sequence_label;
