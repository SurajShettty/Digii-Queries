-- Module: Examination — Result Declaration Report
-- Reproduces the "Result Declaration" grid (per exam / enrollment session).
--
-- IMPORTANT — why the base table is enrollment, not the declaration table:
--   ems_result_declaration_student only holds students who have been DECLARED or
--   BLOCKED. "Not Declared" students have NO row there (they show "--" in the UI).
--   So the row universe = students ENROLLED for the exam, with the declaration
--   table LEFT JOINed on. The UI's "Total Students" counts active enrolled students.
--
-- Category column (combines both UI tabs in one report):
--   Backlog = student has at least one BACKLOG course enrolment for the exam
--   Regular = otherwise
--   (ems_student_course_enrollment.type = 'REGULAR' | 'BACKLOG' | ...)
--   To get just one tab, filter the outer query on `Category`.
--
-- Rule Status:
--   block_reason IS NOT NULL -> 'Blocked'
--   declaration row exists & is_declared = 1 -> 'Declared'
--   no declaration row (or is_declared = 0)  -> 'Not Declared'
--
-- The page header (e.g. "2022-23 Even Semester Examination") is the exam — exam_id = 2.
-- NOTE on student status: the live UI lists only ACTIVE students (exam_id = 2 -> 65).
--   This report INCLUDES deactivated students too (exam_id = 2 -> 66, +1 inactive),
--   flagged in the `Student Status` column. To match the UI exactly, add
--   `AND a.is_active = 1` to the WHERE clause.
-- Find the exam id with:  SELECT id, name FROM ems_examination ORDER BY id;

-- ===========================================================================
-- Main grid — Regular Students tab (one row per student)
-- ===========================================================================
SELECT
    CONCAT(ua.f_name, ' ', ua.l_name)               AS `Student Name`,
    ua.registration_id                              AS `Registration ID`,
    a.email                                         AS `Email`,
    p.programme_name                                AS `Programme`,
    IF(EXISTS (SELECT 1
               FROM ems_student_course_enrollment sce
               JOIN ems_student_programme_enrollment spe2 ON spe2.id = sce.student_programme_enrollment_id
               WHERE spe2.ukid = spe.ukid AND spe2.exam_id = spe.exam_id
                 AND sce.type = 'BACKLOG'),
       'Backlog', 'Regular')                        AS `Category`,
    IF(a.is_active = 1, 'Active', 'Inactive')       AS `Student Status`,
    CASE
        WHEN s.block_reason IS NOT NULL THEN 'Blocked'
        WHEN s.is_declared = 1          THEN 'Declared'
        ELSE 'Not Declared'
    END                                             AS `Rule Status`,
    s.block_reason                                  AS `Block Reason`,
    r.title                                         AS `Rules`,
    CONCAT(ub.f_name, ' ', ub.l_name)               AS `Last Updated By`,
    CONVERT_TZ(s.applied_at, '+00:00', '+05:30')    AS `Last Updated At`
FROM ems_student_programme_enrollment spe
JOIN authenticator   a  ON a.ukid  = spe.ukid       -- includes deactivated students
JOIN user_attributes ua ON ua.ukid = spe.ukid
LEFT JOIN ems_result_declaration_student s
       ON s.student_ukid = spe.ukid AND s.exam_id = spe.exam_id
LEFT JOIN ems_result_declaration_rule r ON r.id = s.rule_id
LEFT JOIN student_profile sp ON sp.ukid = spe.ukid
LEFT JOIN programme       p  ON p.programme_id = sp.programme_id
LEFT JOIN user_attributes ub ON ub.ukid = s.applied_by
WHERE spe.exam_id = 2                                              -- <- target exam
GROUP BY spe.ukid
ORDER BY `Category`, `Student Name`;


-- ===========================================================================
-- Summary cards (Total Students / Declared / Not Declared / Blocked)
-- ===========================================================================
SELECT
    IF(EXISTS (SELECT 1
               FROM ems_student_course_enrollment sce
               JOIN ems_student_programme_enrollment spe2 ON spe2.id = sce.student_programme_enrollment_id
               WHERE spe2.ukid = spe.ukid AND spe2.exam_id = spe.exam_id
                 AND sce.type = 'BACKLOG'),
       'Backlog', 'Regular')                                                                         AS `Category`,
    COUNT(DISTINCT spe.ukid)                                                                         AS `Total Students`,
    COUNT(DISTINCT CASE WHEN s.is_declared = 1 AND s.block_reason IS NULL THEN spe.ukid END)          AS `Declared`,
    COUNT(DISTINCT CASE WHEN s.id IS NULL OR (s.is_declared = 0 AND s.block_reason IS NULL)
                        THEN spe.ukid END)                                                            AS `Not Declared`,
    COUNT(DISTINCT CASE WHEN s.block_reason IS NOT NULL THEN spe.ukid END)                            AS `Blocked`
FROM ems_student_programme_enrollment spe
JOIN authenticator a ON a.ukid = spe.ukid           -- includes deactivated students
LEFT JOIN ems_result_declaration_student s
       ON s.student_ukid = spe.ukid AND s.exam_id = spe.exam_id
WHERE spe.exam_id = 2
GROUP BY `Category` WITH ROLLUP;


-- ===========================================================================
-- Optional: course-level breakdown (the "Course > View" drill-down)
-- One row per student-course enrolment for the exam.
-- ===========================================================================
SELECT
    CONCAT(ua.f_name, ' ', ua.l_name)               AS `Student Name`,
    ua.registration_id                              AS `Registration ID`,
    p.programme_name                                AS `Programme`,
    crs.course_code                                 AS `Course Code`,
    crs.course_name                                 AS `Course Name`,
    sce.type                                        AS `Course Type`,
    IF(a.is_active = 1, 'Active', 'Inactive')       AS `Student Status`,
    CASE
        WHEN s.block_reason IS NOT NULL THEN 'Blocked'
        WHEN s.is_declared = 1          THEN 'Declared'
        ELSE 'Not Declared'
    END                                             AS `Rule Status`,
    r.title                                         AS `Rules`
FROM ems_student_programme_enrollment spe
JOIN authenticator   a  ON a.ukid  = spe.ukid       -- includes deactivated students
JOIN user_attributes ua ON ua.ukid = spe.ukid
JOIN ems_student_course_enrollment sce ON sce.student_programme_enrollment_id = spe.id
LEFT JOIN term_course tc  ON tc.id  = sce.term_course_id
LEFT JOIN course      crs ON crs.course_id = tc.course_id
LEFT JOIN ems_result_declaration_student s
       ON s.student_ukid = spe.ukid AND s.exam_id = spe.exam_id
LEFT JOIN ems_result_declaration_rule r ON r.id = s.rule_id
LEFT JOIN student_profile sp ON sp.ukid = spe.ukid
LEFT JOIN programme       p  ON p.programme_id = sp.programme_id
WHERE spe.exam_id = 2
ORDER BY `Student Name`, crs.course_code;
