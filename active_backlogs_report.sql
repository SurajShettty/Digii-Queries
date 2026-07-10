SELECT
    sp.ukid                                                              AS student_ukid,
    TRIM(CONCAT(COALESCE(ua.f_name,''),' ',COALESCE(ua.l_name,'')))      AS student_name,
    au.email                                                            AS student_email,
    sp.roll_number,
    sp.registration_id,
    prog.programme_code,
    prog.programme_name,
    dept.department_name,
    c.course_id,
    c.course_code,
    c.course_name,
    c.course_credits,
    latest.grade,
    latest.re_exam_grade,
    latest.term_name
FROM student_profile sp
JOIN      user_attributes ua  ON ua.ukid          = sp.ukid            -- student name
LEFT JOIN authenticator au    ON au.ukid          = sp.ukid            -- login email
LEFT JOIN programme prog      ON prog.programme_id = sp.programme_id
LEFT JOIN department dept     ON dept.department_id = sp.department_id
/* --- one row per (student, course) that is an ACTIVE, uncleared backlog --- */
JOIN (
    SELECT g.student_ukid, g.course_id,
           MAX(CASE WHEN g.is_failed = 1
                     AND (g.re_exam_grade IS NULL OR g.re_exam_grade IN ('F','U','AB','NEE','Z'))
                    THEN 1 ELSE 0 END) AS has_open_fail,
           MAX(CASE WHEN (g.is_failed = 0 AND g.grade IS NOT NULL AND g.grade NOT IN ('F','U','AB','NEE','Z'))
                      OR (g.re_exam_grade IS NOT NULL AND g.re_exam_grade NOT IN ('F','U','AB','NEE','Z'))
                    THEN 1 ELSE 0 END) AS has_pass
    FROM ems_examination_student_course_grade g
    GROUP BY g.student_ukid, g.course_id
    HAVING has_open_fail = 1 AND has_pass = 0
) bl ON bl.student_ukid = sp.ukid
JOIN course c ON c.course_id = bl.course_id
/* --- grade / term shown from the most recent failing attempt of that course --- */
JOIN (
    SELECT x.student_ukid, x.course_id, x.grade, x.re_exam_grade, t.name AS term_name,
           ROW_NUMBER() OVER (PARTITION BY x.student_ukid, x.course_id ORDER BY x.id DESC) rn
    FROM ems_examination_student_course_grade x
    LEFT JOIN term_course tc ON tc.id = x.term_course_id
    LEFT JOIN term t         ON t.id  = tc.term_id
    WHERE x.is_failed = 1
) latest
    ON latest.student_ukid = bl.student_ukid
   AND latest.course_id    = bl.course_id
   AND latest.rn = 1
WHERE sp.ukid = 548467          -- <<< change this to your student
ORDER BY c.course_code;