-- Course registration report with ACTUAL applicable fee and fees paid,
-- resolved from the EMS enrollment-fee-settings chain instead of hardcoded 500/5000.
--
-- Fee resolution chain (per student, per course):
--   t2.exam_id -> ems_enrollment_session.exam_id
--              -> ems_enrollment_session_settings (matched to the student's own
--                 term_programme_batch: same term, programme, intake)
--              -> ems_enrollment_session_fee_settings (enrollment_fee_type decides
--                 which child table holds the actual amount)
--
-- enrollment_fee_type branches:
--   FIXED             -> esfs.fixed_fee_amount
--   COURSE_WISE       -> esfs.fee_per_course
--   COURSE_CREDIT     -> ems_enrollment_session_fee_credit_settings, matched by
--                        tc.course_credits falling within credit_lower/upper_limit
--   CUSTOM_COURSE_FEE -> ems_enrollment_session_custom_course_fee_settings, matched
--                        by term_course_id
--   COURSE_TYPE       -> ems_enrollment_session_fee_course_type_settings (not
--                        currently exercised by any tenant's data; included for
--                        completeness, may need a course_component_type match if
--                        a college ever uses it)
--   t1.override_fee_amount always takes precedence over the computed amount, same
--   as the original query's intent.
--
-- Fees_Paid caveat: dues_v2 records are created per enrollment SESSION, not per
-- course -- multiple courses in the same registration can share one dues_v2_id.
-- There is no per-course split of a partially paid due in the data. So Fees_Paid
-- here means "this course's computed fee, counted as paid only if its linked due
-- is fully CLEARED" -- it is not a true prorated share of a partial payment.
--
-- Tested against collpoll_gdgu term 145 (fee settings actually configured there).
-- Run against a schema/term that has ems_enrollment_session_fee_settings populated
-- for it to return non-zero fees -- most tenants (e.g. collpoll_wud) have none
-- configured, so Applicable_Fee/Fees_Paid will be 0 there regardless of this query.

SELECT
    tc.id,
    t1.enrollment_status AS 'Enrollment_Status',
    t.name Term_Name,
    ee.name Exam_Name,
    eet.name Exam_Type,
    ua.registration_id AS Registration,
    CONCAT(ua.f_name, ' ', ua.l_name) Student_Name,
    d.department_name AS 'Department_Name',
    p.programme_name AS 'Program_Name',
    cv.course_name,
    t3.course_code,
    t1.type AS 'Course_Type',
    sp.year_of_joining,
    esfs.enrollment_fee_type AS Fee_Basis,
    ROUND(COALESCE(
        t1.override_fee_amount,
        CASE esfs.enrollment_fee_type
            WHEN 'FIXED'             THEN esfs.fixed_fee_amount
            WHEN 'COURSE_WISE'       THEN esfs.fee_per_course
            WHEN 'COURSE_CREDIT'     THEN escfs.fee_amount
            WHEN 'CUSTOM_COURSE_FEE' THEN esccfs.fee_amount
            WHEN 'COURSE_TYPE'       THEN esctts.fee_amount
            ELSE NULL
        END
    ), 0) AS Applicable_Fee,
    IF(due.status = 'CLEARED',
       ROUND(COALESCE(
            t1.override_fee_amount,
            CASE esfs.enrollment_fee_type
                WHEN 'FIXED'             THEN esfs.fixed_fee_amount
                WHEN 'COURSE_WISE'       THEN esfs.fee_per_course
                WHEN 'COURSE_CREDIT'     THEN escfs.fee_amount
                WHEN 'CUSTOM_COURSE_FEE' THEN esccfs.fee_amount
                WHEN 'COURSE_TYPE'       THEN esctts.fee_amount
                ELSE NULL
            END
       ), 0),
       0) AS Fees_Paid,
    IF(due.status IS NULL AND t1.added_by IS NULL, 'No Dues Found', due.status) AS Dues_Status,
    IF(t1.attendance_eligibility = 1, 'Eligible', 'Not Eligible') attendance_eligibility,
    CONCAT(ua1.f_name, ' ', ua1.l_name) Added_Explicitly_By
FROM
    ems_student_course_enrollment t1
        LEFT JOIN
    ems_student_programme_enrollment t2 ON t1.student_programme_enrollment_id = t2.id
        LEFT JOIN
    term_course tc ON t1.term_course_id = tc.id
        LEFT JOIN
    course_version cv ON tc.course_version_id = cv.id
        LEFT JOIN
    course t3 ON cv.course_id = t3.course_id
        LEFT JOIN
    term t ON t.id = tc.term_id
        LEFT JOIN
    ems_examination ee ON ee.id = t2.exam_id
        LEFT JOIN
    ems_examination_type eet ON eet.id = t2.exam_type_id
        LEFT JOIN
    user_attributes ua ON ua.ukid = t2.ukid
        LEFT JOIN
    user_attributes ua1 ON ua1.ukid = t1.added_by
        LEFT JOIN
    student_profile sp ON sp.ukid = ua.ukid
        LEFT JOIN
    department d ON d.department_id = sp.department_id
        LEFT JOIN
    programme p ON p.programme_id = sp.programme_id
        -- fee resolution chain: match the student's own term/programme/intake batch
        LEFT JOIN
    term_programme_batch tpb ON tpb.term_id = tc.term_id
        AND tpb.programme_id = sp.programme_id
        AND tpb.intake_id = sp.intake_id
        LEFT JOIN
    ems_enrollment_session es ON es.exam_id = t2.exam_id
        LEFT JOIN
    ems_enrollment_session_settings ess ON ess.enrollment_session_id = es.id
        AND ess.term_programme_batch_id = tpb.id
        LEFT JOIN
    ems_enrollment_session_fee_settings esfs ON esfs.session_settings_id = ess.id
        LEFT JOIN
    ems_enrollment_session_fee_credit_settings escfs ON escfs.fee_settings_id = esfs.id
        AND tc.course_credits BETWEEN escfs.credit_lower_limit AND escfs.credit_upper_limit
        LEFT JOIN
    ems_enrollment_session_custom_course_fee_settings esccfs ON esccfs.fee_settings_id = esfs.id
        AND esccfs.term_course_id = t1.term_course_id
        LEFT JOIN
    ems_enrollment_session_fee_course_type_settings esctts ON esctts.fee_settings_id = esfs.id
        -- actual dues status for this course's registration (session-level, see caveat above)
        LEFT JOIN
    dues_v2 due ON due.id = t1.dues_v2_id
WHERE
    t.id IN (145)
        AND eet.name IN ('ETE' , 'ETE Practical',
        'Reappear/Repeat Exam',
        'Theory/practical and jury');
