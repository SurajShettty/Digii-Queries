-- Module: Examination - Graduation Eligibility Report (Course-Level)
-- One row per student per term per OPTED course, showing that course's credit,
-- latest grade, and earned/passed flags, plus the term's cumulative CGPA repeated on every row.
--
-- This is the course-level expansion of graduation_eligibility_report.sql:
-- the term-level report SUMs credits per term; this report keeps each opted
-- course as its own row so you can see exactly which courses drove the totals.
--
-- Scope: TERM+COURSE-WISE per student. Result = one row per student per term per
-- REGULAR opted course_id in that term.
--
-- OPTED (counted at term_course granularity) -- the student's REGULAR registrations:
--   ems_student_course_enrollment.enrollment_status IN ('ENROLLED','AUTO_ENROLLED') AND type='REGULAR'.
--   * BACKLOG rows are re-attempts of an already-opted course and must NOT appear as separate
--     opted rows -> excluded (they still feed the latest-grade lookup below).
--   * A course taken as REGULAR in two different terms appears once in each term's rows.
--   * NOT_ENROLLED = offered but not opted -> excluded.
--
-- EARNED / PASSED / GRADE (per COURSE within the opted term):
--   Based on the student's LATEST grade attempt for that course_id (across all attempts,
--   including later backlogs), so a later cleared backlog marks the course earned, while a
--   later failed/NE backlog attempt keeps it unearned even though it was opted in this term.
--
-- Column definitions:
--   Course Credits = COALESCE(term_course.course_credits, course_version.course_credits).
--   Grade / Grade Point = the latest attempt's grade (prefers re-exam grade if that attempt
--                          is what carries the latest key and has a re-exam grade recorded).
--   Earned Credits = NULL if the latest attempt has no grade point recorded at all
--              (not graded yet); else Course Credits if that attempt qualifies as earned
--              (is_failed=0 AND grade_point NOT NULL) OR (is_failed_for_re_exam=0
--              AND re_exam_grade_point NOT NULL); else 0 (graded but not earned).
--   Passed?  = latest attempt passed, incl. non-graded/satisfactory results:
--              (is_failed=0 AND (grade NOT NULL OR grade_point NOT NULL))
--              OR (is_failed_for_re_exam=0 AND (re_exam_grade NOT NULL OR re_exam_grade_point NOT NULL)).
--   CGPA     = positive cumulative CGPA recorded for that term (same value on every course
--              row for that student+term -- it is a term-level figure, not a course-level one).
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
    if(a.is_active=1,'Active','Inactive')            AS `Is Active?`,
    CONCAT(ua.f_name, ' ', COALESCE(ua.l_name, ''))  AS `Student Name`,
    oa.course_code                                   AS `Course Code`,
    oa.course_name                                   AS `Course Name`,
    oa.cr                                            AS `Course Credits`,
    cp.grade                                         AS `Grade`,
    cp.grade_point                                   AS `Grade Point`,
    CASE
        WHEN cp.grade_point IS NULL THEN NULL
        WHEN cp.earned = 1 THEN oa.cr
        ELSE 0
    END                                               AS `Earned Credits`,
    CASE WHEN cp.passed = 1 THEN 'Y' ELSE 'N' END    AS `Passed?`,
    round(cgpa.cgpa,2)                                         AS `CGPA`
FROM (

    SELECT DISTINCT spe.ukid,
           ee.term_id,
           t.name AS term_name,
           t.acad_year_start,
           t.sequence AS term_sequence,
           sce.term_course_id,
           tc.course_id,
           COALESCE(tc.course_code, c.course_code)  AS course_code,
           COALESCE(tc.course_name, c.course_name)  AS course_name,
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
    LEFT JOIN course c
        ON c.course_id = tc.course_id
) oa
LEFT JOIN (
    SELECT g.student_ukid,
           g.course_id,
           COALESCE(NULLIF(g.re_exam_grade,''), g.grade)       AS grade,
           COALESCE(g.re_exam_grade_point, g.grade_point)      AS grade_point,
           CASE
               WHEN (g.is_failed = 0 AND g.grade_point IS NOT NULL)
                 OR (g.is_failed_for_re_exam = 0 AND g.re_exam_grade_point IS NOT NULL)
               THEN 1 ELSE 0
           END AS earned,
           CASE
               WHEN (g.is_failed = 0 AND (g.grade IS NOT NULL OR g.grade_point IS NOT NULL))
                 OR (g.is_failed_for_re_exam = 0 AND (g.re_exam_grade IS NOT NULL OR g.re_exam_grade_point IS NOT NULL))
               THEN 1 ELSE 0
           END AS passed
    FROM ems_examination_student_course_grade g
    JOIN ems_examination ge
        ON ge.id = g.examination_id
    JOIN term gt
        ON gt.id = ge.term_id
    JOIN (
        SELECT g2.student_ukid,
               g2.course_id,
               MAX(CONCAT(
                   DATE_FORMAT(COALESCE(t2.starts, '1000-01-01'), '%Y%m%d%H%i%s'),
                   LPAD(ee2.id, 10, '0'),
                   LPAD(g2.id, 10, '0')
               )) AS latest_key
        FROM ems_examination_student_course_grade g2
        JOIN ems_examination ee2
            ON ee2.id = g2.examination_id
        JOIN term t2
            ON t2.id = ee2.term_id
        GROUP BY
            g2.student_ukid,
            g2.course_id
    ) latest_grade
        ON latest_grade.student_ukid = g.student_ukid
       AND latest_grade.course_id = g.course_id
       AND latest_grade.latest_key = CONCAT(
           DATE_FORMAT(COALESCE(gt.starts, '1000-01-01'), '%Y%m%d%H%i%s'),
           LPAD(ge.id, 10, '0'),
           LPAD(g.id, 10, '0')
       )
) cp
    ON cp.student_ukid = oa.ukid
   AND cp.course_id = oa.course_id
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
LEFT JOIN authenticator a ON a.ukid = ua.ukid
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
    oa.term_name,
    oa.course_code;
