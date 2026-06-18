-- Module: Examination — Active Backlogs (Student × Course)
-- Lists every ACTIVE backlog (a course a student has failed and not yet cleared),
-- with student details, course details and term details.
--
-- Definition of "active backlog" (ported 1:1 from active_backlog_student_course_list.py):
--   For each (student, course) keep only the LATEST attempt, then it is an active
--   backlog when the student is still failed after that attempt / re-exam:
--       re_exam_grade IS NULL     AND is_failed = 1                              -> active backlog
--    OR re_exam_grade IS NOT NULL AND is_failed_for_re_exam = 1 AND is_failed = 1 -> active backlog
--   (If the re-exam was cleared, or a later attempt passed, it is NOT a backlog.)
--
-- "Latest attempt" = the attempt belonging to the most recent EXAM term (a course
-- can be enrolled across several exams; the newest exam term is the current verdict).
-- We dedupe with ROW_NUMBER() (= pandas drop_duplicates(keep='last') in the script).
--
-- Enrollment filter mirrors the script: only approved/enrolled (or auto-enrolled) rows.
-- Scope it by adding e.g.  AND p.programme_id IN (...)  /  AND esp.exam_id = <id>
-- inside the CTE's WHERE clause.

WITH attempts AS (
    SELECT
        esp.ukid,
        tc.course_id,
        -- ---- student details ----
        ua.registration_id,
        CONCAT(ua.f_name, ' ', ua.l_name)        AS student_name,
        auth.email,
        auth.is_active,
        p.programme_name,
        sp.year_of_joining,
        spec.name                                AS specialisation,
        crt.name                                 AS course_registration_type,
        -- ---- course details ----
        tc.course_code,
        tc.course_name,
        tc.course_credits,
        esc.type                                 AS enrollment_type,   -- REGULAR / BACKLOG / ...
        d.department_name,
        -- ---- term details (the term the course belongs to) ----
        ct.id                                    AS term_id,
        ct.name                                  AS term_name,
        ct.starts                                AS term_starts,
        -- ---- exam + grade ----
        ee.name                                  AS exam_name,
        eesc.grade,
        eesc.grade_point,
        eesc.marks,
        eesc.re_exam_grade,
        eesc.re_exam_marks,
        IFNULL(eesc.is_failed, 0)                AS is_failed,
        IFNULL(eesc.is_failed_for_re_exam, 0)    AS is_failed_for_re_exam,
        -- keep the latest attempt per (student, course) by exam-term start date
        ROW_NUMBER() OVER (
            PARTITION BY esp.ukid, tc.course_id
            ORDER BY et.starts DESC, ee.id DESC
        )                                        AS rn
    FROM ems_student_programme_enrollment esp
    JOIN ems_student_course_enrollment    esc  ON esc.student_programme_enrollment_id = esp.id
    JOIN ems_examination                  ee   ON ee.id  = esp.exam_id
    JOIN term_course                      tc   ON tc.id  = esc.term_course_id
    LEFT JOIN ems_examination_student_course_grade eesc
           ON eesc.term_course_id = tc.id AND eesc.student_ukid = esp.ukid
    LEFT JOIN term        et  ON et.id = ee.term_id          -- exam term (orders the attempts)
    LEFT JOIN term        ct  ON ct.id = tc.term_id          -- course term (for display)
    LEFT JOIN course      co  ON co.course_id     = tc.course_id
    LEFT JOIN department  d   ON d.department_id  = co.department_id
    LEFT JOIN student_profile sp ON sp.ukid = esp.ukid
    LEFT JOIN programme   p   ON p.programme_id   = sp.programme_id
    LEFT JOIN user_attributes ua  ON ua.ukid   = esp.ukid
    LEFT JOIN authenticator   auth ON auth.ukid = esp.ukid
    LEFT JOIN ems_student_course_registration_details escrd
           ON escrd.term_course_id = tc.id AND escrd.ukid = esp.ukid
    LEFT JOIN course_registration_type crt ON crt.id = escrd.course_registration_type_id
    LEFT JOIN programme_specialisation_mapping psm ON psm.id = escrd.programme_specialisation_mapping_id
    LEFT JOIN specialisation spec ON spec.id = psm.specialisation_id
    WHERE ( (esp.enrollment_status = 'APPROVED' AND esc.enrollment_status = 'ENROLLED')
            OR esc.enrollment_status = 'AUTO_ENROLLED' )
)
SELECT
    -- student
    registration_id            AS `Registration ID`,
    student_name               AS `Student Name`,
    email                      AS `Email`,
    IF(is_active = 1, 'Active', 'Inactive') AS `Student Status`,
    programme_name             AS `Programme`,
    specialisation             AS `Specialisation`,
    year_of_joining            AS `Year of Joining`,
    -- course
    course_code                AS `Course Code`,
    course_name                AS `Course Name`,
    course_credits             AS `Course Credits`,
    department_name            AS `Department`,
    enrollment_type            AS `Enrollment Type`,
    course_registration_type   AS `Course Registration Type`,
    -- term
    term_name                  AS `Term`,
    term_starts                AS `Term Starts`,
    -- latest verdict
    exam_name                  AS `Latest Exam`,
    grade                      AS `Grade`,
    marks                      AS `Marks`,
    re_exam_grade              AS `Re-exam Grade`,
    re_exam_marks              AS `Re-exam Marks`
FROM attempts
WHERE rn = 1                                                    -- latest attempt per student-course
  AND (
        (re_exam_grade IS NULL     AND is_failed = 1)
     OR (re_exam_grade IS NOT NULL AND is_failed_for_re_exam = 1 AND is_failed = 1)
      )
ORDER BY `Registration ID`, `Course Code`;
