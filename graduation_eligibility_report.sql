-- Module: Examination — Graduation Eligibility Report
-- One row per student showing CUMULATIVE opted / earned / passed credits and current CGPA,
-- used to judge whether a student has cleared enough credits to graduate.
-- Validated end-to-end against the EMS schema on multiple tenants:
--   collpoll_university: ukid 392838 -> 70 opted / 18 earned, CGPA 8;  ukid 1739136 -> 44 / 3, CGPA 0.91.
--   collpoll_iilmgg    : ukid 1685929 -> 103 opted / 87 earned.
--
-- Scope: CUMULATIVE per student across ALL their examinations. Result = one row per student.
--
-- OPTED (counted at term_course granularity) -- the student's REGULAR registrations:
--   ems_student_course_enrollment.enrollment_status IN ('ENROLLED','AUTO_ENROLLED') AND type='REGULAR'.
--   * BACKLOG rows are re-attempts of an already-opted course and must NOT add opted credits -> excluded.
--   * A course taken as REGULAR in two different terms counts TWICE (we do NOT dedupe opted by course).
--   * NOT_ENROLLED = offered but not opted -> excluded.
--
-- EARNED / PASSED (counted at COURSE granularity -- once per distinct opted course):
--   A course counts as earned/passed if it was cleared in ANY attempt, looked up across ALL of the
--   student's grade rows for that course_id -- NOT just the opted term_course's own grade. This is
--   essential: a course can be failed on the registration we treat as "opted" yet passed in another
--   attempt (e.g. ukid 1685929 course 574: F in one exam, A+ in another -> must count as earned).
--   Because earned is per distinct course, a course registered twice as REGULAR still earns once
--   (keeps ukid 392838 at 18 earned while opted counts it twice).
--
-- Column definitions:
--   Total Opted Course Count   = # regular opted term_courses.
--   Total Opted Course Credits = SUM of their credits.
--   Total Earned Credits       = credits of distinct opted courses passed WITH a grade point (toward CGPA).
--   Total pass credits         = credits of ALL passed distinct opted courses, incl. non-graded /
--                                satisfactory -> Total pass credits >= Total Earned Credits.
--   CGPA                       = the student's LATEST TERM cumulative CGPA (see note below).
--
-- CREDITS come from course_version, not term_course: term_course.course_credits is NULL in this
--   schema; the real value is course_version.course_credits -> COALESCE(tc.course_credits, cv.course_credits).
--
-- PASS RULE (per attempt) -- schema-specific, from data evidence:
--   Use `is_failed` (reliable per-attempt pass flag) paired with "a result exists"; also credit an
--   in-place re-exam via is_failed_for_re_exam. Do NOT use `is_failed_course_result` -- it is a
--   "result declared" gate that stays 1 even for passing grades in undeclared exams.
--     passed = (is_failed = 0            AND (grade IS NOT NULL OR grade_point IS NOT NULL))
--              OR (is_failed_for_re_exam = 0 AND (re_exam_grade IS NOT NULL OR re_exam_grade_point IS NOT NULL))
--     earned = (is_failed = 0            AND grade_point IS NOT NULL)
--              OR (is_failed_for_re_exam = 0 AND re_exam_grade_point IS NOT NULL)
--
-- CGPA with multiple terms: each student has one cgpa row per exam. We take the row of the most
--   recent TERM (term.starts DESC) that has a POSITIVE cgpa -- term chronology, NOT generated_timestamp
--   (often identical across terms from bulk generation, and can be newer on a regenerated older term).
--   A cgpa of 0 is treated as "not yet computed" and skipped: cumulative CGPA cannot fall to 0 once
--   any credit is earned, so a 0 on the latest term is a placeholder for an unprocessed exam (e.g.
--   ukid 1721467 shows 0.81 from the last graded term, not the 0.00 placeholder on the newest term).
--   Falls back to the latest term with a positive cgpa. COALESCE/NULLIF prefer re_exam_cgpa (when
--   non-zero) over cgpa.
--
-- Term Name / Semester = the student's CURRENT standing: Term Name = term of their latest exam;
--   Semester = student_profile.sequence_id. (Credits are all-time cumulative.)
--
-- MySQL 5.x: no CTEs -- built from derived tables. For a large tenant, push the batch filter into
--   the two derived tables (add `JOIN student_profile spf ON spf.ukid = spe.ukid AND spf.year_of_joining = ...`)
--   so they don't aggregate every student.

SELECT
    d.department_name                              AS `Department Name`,
    p.programme_name                               AS `Programme Name`,
    ( SELECT t.name
        FROM ems_student_programme_enrollment spe2
        JOIN ems_examination ee2 ON ee2.id = spe2.exam_id
        JOIN term t              ON t.id   = ee2.term_id
       WHERE spe2.ukid = oa.ukid
       ORDER BY t.starts DESC, ee2.id DESC LIMIT 1 ) AS `Term Name`,
    sp.year_of_joining                             AS `Batch`,
    sp.sequence_id                                 AS `Semester`,
    ua.registration_id                             AS `Registration Id`,
    CONCAT(ua.f_name, ' ', COALESCE(ua.l_name, '')) AS `Student Name`,
    oa.opted_count                                 AS `Total Opted Course Count`,
    oa.opted_credits                               AS `Total Opted Course Credits`,
    ea.earned_credits                              AS `Total Earned Credits`,
    ea.pass_credits                                AS `Total pass credits`,
    ( SELECT COALESCE(NULLIF(c.re_exam_cgpa, 0), c.cgpa)
        FROM ems_examination_student_cgpa c
        JOIN ems_examination ee3 ON ee3.id = c.exam_id
        LEFT JOIN term t3        ON t3.id  = ee3.term_id
       WHERE c.student_ukid = oa.ukid
         AND COALESCE(NULLIF(c.re_exam_cgpa, 0), c.cgpa) > 0
       ORDER BY t3.starts DESC, c.generated_timestamp DESC, c.exam_id DESC LIMIT 1 ) AS `CGPA`
FROM (
    -- OPTED, at term_course granularity: distinct REGULAR term_courses per student
    SELECT o.ukid, COUNT(*) AS opted_count, SUM(o.cr) AS opted_credits
    FROM (
        SELECT DISTINCT spe.ukid, sce.term_course_id,
               COALESCE(tc.course_credits, cv.course_credits) AS cr
        FROM ems_student_programme_enrollment spe
        JOIN ems_student_course_enrollment sce
          ON sce.student_programme_enrollment_id = spe.id
         AND sce.enrollment_status IN ('ENROLLED','AUTO_ENROLLED')
         AND sce.type = 'REGULAR'
        LEFT JOIN term_course   tc ON tc.id = sce.term_course_id
        LEFT JOIN course_version cv ON cv.id = tc.course_version_id
    ) o
    GROUP BY o.ukid
) oa
JOIN (
    -- EARNED / PASSED, at course granularity: distinct opted course cleared in ANY attempt
    SELECT oc.ukid,
           SUM(CASE WHEN cp.earned = 1 THEN oc.cr ELSE 0 END) AS earned_credits,
           SUM(CASE WHEN cp.passed = 1 THEN oc.cr ELSE 0 END) AS pass_credits
    FROM (
        SELECT spe.ukid, tc.course_id,
               MAX(COALESCE(tc.course_credits, cv.course_credits)) AS cr
        FROM ems_student_programme_enrollment spe
        JOIN ems_student_course_enrollment sce
          ON sce.student_programme_enrollment_id = spe.id
         AND sce.enrollment_status IN ('ENROLLED','AUTO_ENROLLED')
         AND sce.type = 'REGULAR'
        LEFT JOIN term_course   tc ON tc.id = sce.term_course_id
        LEFT JOIN course_version cv ON cv.id = tc.course_version_id
        GROUP BY spe.ukid, tc.course_id
    ) oc
    LEFT JOIN (
        -- pass/earned per (student, course) across every attempt of that course
        SELECT student_ukid, course_id,
               MAX(CASE WHEN (is_failed = 0            AND grade_point        IS NOT NULL)
                         OR (is_failed_for_re_exam = 0 AND re_exam_grade_point IS NOT NULL)
                        THEN 1 ELSE 0 END) AS earned,
               MAX(CASE WHEN (is_failed = 0            AND (grade IS NOT NULL OR grade_point IS NOT NULL))
                         OR (is_failed_for_re_exam = 0 AND (re_exam_grade IS NOT NULL OR re_exam_grade_point IS NOT NULL))
                        THEN 1 ELSE 0 END) AS passed
        FROM ems_examination_student_course_grade
        GROUP BY student_ukid, course_id
    ) cp ON cp.student_ukid = oc.ukid AND cp.course_id = oc.course_id
    GROUP BY oc.ukid
) ea ON ea.ukid = oa.ukid
JOIN      user_attributes ua ON ua.ukid = oa.ukid
LEFT JOIN student_profile sp ON sp.ukid = oa.ukid
LEFT JOIN programme p        ON p.programme_id  = sp.programme_id
LEFT JOIN department d       ON d.department_id = p.department_id
WHERE sp.year_of_joining = 2022        -- <<< target batch (cohort); adjust or remove
  -- AND p.programme_id = <programme>  -- optional: restrict to one programme
ORDER BY d.department_name, p.programme_name, `Student Name`;
