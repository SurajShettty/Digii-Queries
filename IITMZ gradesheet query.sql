WITH total_sessions AS (
    SELECT 
        COUNT(t1.id) AS attendan,
        cs.ukid,
        c.term_id,
        c.id as class_id,
        cc.course_code,
        ua.registration_id
    FROM timetable_lesson_course_class t1
    LEFT JOIN lesson l ON t1.lesson_id = l.id
    LEFT JOIN class_student cs ON cs.class_id = t1.class_id
    LEFT JOIN class_attendance ca ON ca.lesson_id = t1.lesson_id AND ca.ukid = cs.ukid
    LEFT JOIN UDC_09_USER_ATTENDANCE_STATUS udc ON udc.id = ca.status_id
    LEFT JOIN class c ON c.id = ca.class_id
    LEFT JOIN course cc ON cc.course_id = c.course_id
    LEFT JOIN user_attributes ua ON ua.ukid = cs.ukid
    WHERE 
        l.is_cancelled = 0
        AND t1.attendance_taken IS NOT NULL
        AND udc.final_status != 'DO_NOT_CONSIDER_FOR_ATTENDANCE'
        AND DATE(l.start) >= DATE(cs.created_timestamp)
    GROUP BY cs.ukid, ca.class_id
),

present_sessions AS (
    SELECT 
        COUNT(t1.id) AS attend1,
        cs.ukid,
        c.id as class_id
    FROM timetable_lesson_course_class t1
    LEFT JOIN lesson l ON t1.lesson_id = l.id
    LEFT JOIN class_student cs ON cs.class_id = t1.class_id
    LEFT JOIN class_attendance ca ON ca.lesson_id = t1.lesson_id AND ca.ukid = cs.ukid
    LEFT JOIN UDC_09_USER_ATTENDANCE_STATUS udc ON udc.id = ca.status_id
    LEFT JOIN class c ON c.id = ca.class_id
    WHERE 
        l.is_cancelled = 0
        AND t1.attendance_taken IS NOT NULL
        AND udc.final_status = 'PRESENT'
        AND DATE(l.start) >= DATE(cs.created_timestamp)
    GROUP BY cs.ukid, ca.class_id
)

SELECT 
    t.name AS term_name,
    t.starts,
    t.id term_id,
    CONCAT('1-', t.name) AS concata,
    CONCAT(t.name,'-', ROW_NUMBER() OVER (PARTITION BY sp.ukid ORDER BY tc.id)) AS course_number_term,
    sp.ukid,
    ua.registration_id,
    CONCAT(ua.registration_id, tc.course_code) AS student_code,
    CONCAT(ua.f_name, ' ', ua.l_name) AS "Student Name",
    d.department_name AS Department,
    p.programme_name AS Programme,
    tc.course_name AS "Course Name",
    tc.course_code AS "Course Code",
    tc.course_credits AS "Course Credit",
    LEFT(co.alt_name, 1) AS Category,
    ROW_NUMBER() OVER (PARTITION BY sp.ukid ORDER BY tc.course_code) AS course_number,
    CONCAT("Course",'-', ROW_NUMBER() OVER (PARTITION BY t.id, sp.ukid ORDER BY tc.course_code)) AS course_code_with_number,
    IF(eesc.moderation_grade IS NULL, eesc.grade, eesc.moderation_grade) AS Grade,
    eesc.grade_point AS "Grade Point",
    eess.sgpa,
    eescq.cgpa,
    IF(eesc.grade IS NULL, '-', IF(eesc.is_failed + eesc.is_failed_for_re_exam >= 1, 'fail', 'pass')) AS status,
    IF(eesc.grade IS NULL OR (eesc.is_failed + eesc.is_failed_for_re_exam) >= 1, 0, tc.course_credits) AS "Earned Point",
--     t1.earned_point,
    ROUND((ps.attend1 / ts.attendan) * 100, 2) AS attendance_percent, -- Adding attendance_percent here,
    CASE 
        WHEN ROUND((ps.attend1 / ts.attendan) * 100, 2) >= 95 THEN 'VG'
        WHEN ROUND((ps.attend1 / ts.attendan) * 100, 2) BETWEEN 85 AND 94 THEN 'G'
        WHEN ROUND((ps.attend1 / ts.attendan) * 100, 2) < 85 THEN 'P'
        WHEN ROUND((ps.attend1 / ts.attendan) * 100, 2) is null then null
        ELSE 'Unknown' 
    END AS "Percentage Grade"

FROM ems_student_programme_enrollment esp
INNER JOIN ems_student_course_enrollment esc ON esc.student_programme_enrollment_id = esp.id
INNER JOIN ems_examination ee ON ee.id = esp.exam_id
INNER JOIN term_course tc ON tc.id = esc.term_course_id
INNER JOIN student_profile sp ON sp.ukid = esp.ukid
INNER JOIN course co ON tc.course_id = co.course_id
INNER JOIN department d ON d.department_id = co.department_id
INNER JOIN programme p ON p.programme_id = sp.programme_id
INNER JOIN ems_examination_student_course_grade eesc ON eesc.term_course_id = tc.id AND eesc.student_ukid = esp.ukid
LEFT JOIN user_attributes ua ON eesc.student_ukid = ua.ukid
INNER JOIN term t ON t.id = tc.term_id
LEFT JOIN ems_examination_student_sgpa eess ON eess.student_ukid = esp.ukid AND eess.exam_id = esp.exam_id
LEFT JOIN ems_examination_student_cgpa eescq ON eescq.student_ukid = esp.ukid AND eescq.exam_id = esp.exam_id
LEFT JOIN (
    SELECT 
        eesc.student_ukid,
        tc.term_id,
        tc.course_id,
        SUM(tc.course_credits) AS earned_point
    FROM ems_examination_student_course_grade eesc 
    LEFT JOIN term_course tc ON tc.id = eesc.term_course_id
    WHERE COALESCE(eesc.is_failed, eesc.is_failed_for_re_exam) = 0
    GROUP BY eesc.student_ukid, tc.term_id, tc.course_id
) t1 ON t1.student_ukid = esp.ukid AND tc.term_id = t1.term_id AND t1.course_id = tc.course_id

-- Joining with attendance data
LEFT JOIN total_sessions ts ON ts.ukid = sp.ukid AND ts.course_code = tc.course_code
LEFT JOIN present_sessions ps ON ts.ukid = ps.ukid AND ts.class_id = ps.class_id

WHERE
--     p.programme_id  IN  (11,12,13)
--     
 p.programme_name='MASTER OF TECHNOLOGY IN DATA SCIENCE AND ARTIFICIAL INTELLIGENCE'
 AND sp.year_of_joining = 2024
-- and 
-- sp.ukid in (1201901,1201836)
GROUP BY
    sp.ukid,
    ua.registration_id,
    d.department_name,
    p.programme_name,
    tc.course_code,
    tc.course_name,
    tc.course_credits,
    t.name,
    eesc.grade,
    CONCAT(ua.f_name, ' ', ua.l_name),
    IF(eesc.moderation_grade IS NULL, eesc.grade, eesc.moderation_grade),
    eesc.grade_point,
    eess.sgpa,
    eescq.cgpa,
    t.starts
ORDER BY
    t.starts ASC,
    sp.ukid,
    course_number ASC