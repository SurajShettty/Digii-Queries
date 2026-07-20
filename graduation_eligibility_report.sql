-- Module: Examination - Graduation Eligibility Report
-- One row per student per term showing opted / earned / passed credits and the term's cumulative CGPA.
--
-- Scope: TERM-WISE per student. Result = one row per student for each term in which the
-- student has REGULAR opted courses.
--
-- OPTED (counted at term_course granularity) -- the student's REGULAR registrations:
--   ems_student_course_enrollment.enrollment_status IN ('ENROLLED','AUTO_ENROLLED') AND type='REGULAR'.
--   * BACKLOG rows are re-attempts of an already-opted course and must NOT add opted credits -> excluded.
--   * A course taken as REGULAR in two different terms appears once in each term row.
--   * NOT_ENROLLED = offered but not opted -> excluded.
--
-- EARNED / PASSED (counted at COURSE granularity within the opted term):
--   A course counts as earned/passed in the term where it was opted if it was cleared in ANY attempt,
--   looked up across ALL of the student's grade rows for that course_id. This keeps later re-attempts
--   from creating extra opted credits, while still crediting the original opted term after the course
--   is cleared.
--
-- Column definitions:
--   Total Opted Course Count   = # regular opted term_courses in that term.
--   Total Opted Course Credits = SUM of their credits in that term.
--   Total Earned Credits       = credits of distinct opted courses passed WITH a grade point.
--   Total pass credits         = credits of ALL passed distinct opted courses, incl. non-graded /
--                                satisfactory -> Total pass credits >= Total Earned Credits.
--   CGPA                       = positive cumulative CGPA recorded for that term.
--
-- CREDITS come from course_version when term_course.course_credits is NULL:
--   COALESCE(tc.course_credits, cv.course_credits).
--
-- PASS RULE (per attempt) -- schema-specific, from data evidence:
--     passed = (is_failed = 0            AND (grade IS NOT NULL OR grade_point IS NOT NULL))
--              OR (is_failed_for_re_exam = 0 AND (re_exam_grade IS NOT NULL OR re_exam_grade_point IS NOT NULL))
--     earned = (is_failed = 0            AND grade_point IS NOT NULL)
--              OR (is_failed_for_re_exam = 0 AND re_exam_grade_point IS NOT NULL)
--
-- MySQL 5.x: no CTEs -- built from derived tables.

SELECT
    d.department_name                                AS `Department Name`,
    p.programme_name                                 AS `Programme Name`,
    oa.term_name                                     AS `Term Name`,
    sp.year_of_joining                               AS `Batch`,
(
    SELECT
        (
            (
                CAST(oa.acad_year_start AS SIGNED)
                - CAST(sp.year_of_joining AS SIGNED)
            )
            *
            CASE
                WHEN p.system = 'semester' THEN 2
                WHEN p.system = 'trimester' THEN 3
                ELSE 1
            END
            +
            CAST(COALESCE(oa.term_sequence,0) AS SIGNED)
        )
) AS `Semester`,
    ua.registration_id                               AS `Registration Id`,
    CONCAT(ua.f_name, ' ', COALESCE(ua.l_name, ''))  AS `Student Name`,
    oa.opted_count                                   AS `Total Opted Course Count`,
    oa.opted_credits                                 AS `Total Opted Course Credits`,
    ea.earned_credits                                AS `Total Earned Credits`,
    ea.pass_credits                                  AS `Total pass credits`,
    round(cgpa.cgpa,2)                                         AS `CGPA`
FROM (

    SELECT o.ukid,
           o.term_id,
           o.term_name,
           o.acad_year_start,
           o.term_sequence,
           COUNT(*) AS opted_count,
           SUM(o.cr) AS opted_credits
    FROM (
        SELECT DISTINCT spe.ukid,
               ee.term_id,
               t.name AS term_name,
               t.acad_year_start,
               t.sequence AS term_sequence,
               sce.term_course_id,
               COALESCE(tc.course_credits, cv.course_credits) AS cr
        FROM ems_student_programme_enrollment spe
        JOIN ems_examination ee
            ON ee.id = spe.exam_id
        JOIN term t
            ON t.id = ee.term_id
        JOIN ems_student_course_enrollment sce
            ON sce.student_programme_enrollment_id = spe.id
           AND sce.enrollment_status IN ('ENROLLED','AUTO_ENROLLED')
           AND sce.type = 'REGULAR'
        LEFT JOIN term_course tc
            ON tc.id = sce.term_course_id
        LEFT JOIN course_version cv
            ON cv.id = tc.course_version_id
    ) o
    GROUP BY
        o.ukid,
        o.term_id,
        o.term_name,
        o.acad_year_start,
        o.term_sequence
) oa
JOIN (

    SELECT oc.ukid,
           oc.term_id,
           SUM(CASE WHEN cp.earned = 1 THEN oc.cr ELSE 0 END) AS earned_credits,
           SUM(CASE WHEN cp.passed = 1 THEN oc.cr ELSE 0 END) AS pass_credits
    FROM (
        SELECT spe.ukid,
               ee.term_id,
               tc.course_id,
               MAX(COALESCE(tc.course_credits, cv.course_credits)) AS cr
        FROM ems_student_programme_enrollment spe
        JOIN ems_examination ee
            ON ee.id = spe.exam_id
        JOIN ems_student_course_enrollment sce
            ON sce.student_programme_enrollment_id = spe.id
           AND sce.enrollment_status IN ('ENROLLED','AUTO_ENROLLED')
           AND sce.type = 'REGULAR'
        LEFT JOIN term_course tc
            ON tc.id = sce.term_course_id
        LEFT JOIN course_version cv
            ON cv.id = tc.course_version_id
        GROUP BY
            spe.ukid,
            ee.term_id,
            tc.course_id
    ) oc
    LEFT JOIN (
        SELECT student_ukid,
               course_id,
               MAX(
                   CASE
                       WHEN (is_failed = 0 AND grade_point IS NOT NULL)
                         OR (is_failed_for_re_exam = 0 AND re_exam_grade_point IS NOT NULL)
                       THEN 1 ELSE 0
                   END
               ) AS earned,
               MAX(
                   CASE
                       WHEN (is_failed = 0 AND (grade IS NOT NULL OR grade_point IS NOT NULL))
                         OR (is_failed_for_re_exam = 0 AND (re_exam_grade IS NOT NULL OR re_exam_grade_point IS NOT NULL))
                       THEN 1 ELSE 0
                   END
               ) AS passed
        FROM ems_examination_student_course_grade
        GROUP BY
            student_ukid,
            course_id
    ) cp
        ON cp.student_ukid = oc.ukid
       AND cp.course_id = oc.course_id
    GROUP BY
        oc.ukid,
        oc.term_id
) ea
    ON ea.ukid = oa.ukid
   AND ea.term_id = oa.term_id
LEFT JOIN (
    SELECT c1.student_ukid,
           ee1.term_id,
           COALESCE(NULLIF(c1.re_exam_cgpa, 0), c1.cgpa) AS cgpa
    FROM ems_examination_student_cgpa c1
    JOIN ems_examination ee1
        ON ee1.id = c1.exam_id
    JOIN (
        SELECT c2.student_ukid,
               ee2.term_id,
               MAX(c2.id) AS max_id
        FROM ems_examination_student_cgpa c2
        JOIN ems_examination ee2
            ON ee2.id = c2.exam_id
        WHERE COALESCE(NULLIF(c2.re_exam_cgpa, 0), c2.cgpa) > 0
        GROUP BY
            c2.student_ukid,
            ee2.term_id
    ) latest
        ON latest.student_ukid = c1.student_ukid
       AND latest.term_id = ee1.term_id
       AND latest.max_id = c1.id
) cgpa
    ON cgpa.student_ukid = oa.ukid
   AND cgpa.term_id = oa.term_id
JOIN user_attributes ua
    ON ua.ukid = oa.ukid
LEFT JOIN student_profile sp
    ON sp.ukid = oa.ukid
LEFT JOIN programme p
    ON p.programme_id = sp.programme_id
LEFT JOIN department d
    ON d.department_id = p.department_id

ORDER BY
    d.department_name,
    p.programme_name,
    `Student Name`,
    `Semester`,
    oa.term_name;
    SELECT VERSION();
