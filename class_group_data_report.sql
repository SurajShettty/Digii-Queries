-- Class Group Data Report
-- One row per student per class group (cohort), for the selected terms.
-- Columns: Class Group Name, Course Code, Term, Faculty Name(s), Student Registration ID,
-- Student Name, Enrollment Type (course registration type: Core Courses, Programme Electives,
-- Open Electives, Primer, Zero Credit, etc.).
--
-- Change the term ids in filtered_terms to target different terms.
--
-- Notes:
--  * Faculty are aggregated per class group (comma-separated) so student rows are not multiplied
--    when a class group has multiple faculty.
--  * Enrollment Type comes from ams_student_course (ukid + course + term). Students added to a class
--    group without a matching course registration show 'Not Mapped'.

WITH filtered_terms AS (
    SELECT id AS term_id, name AS term_name
    FROM term
    WHERE id IN (85, 86)                       -- <== set required term ids
),
class_faculty_names AS (
    SELECT
        cf.class_id,
        GROUP_CONCAT(DISTINCT TRIM(CONCAT(ua.f_name, ' ', COALESCE(ua.l_name, '')))
                     ORDER BY ua.f_name SEPARATOR ', ') AS faculty_names
    FROM class_faculty cf
    JOIN user_attributes ua ON ua.ukid = cf.faculty_id
    GROUP BY cf.class_id
)
SELECT
    c.batch                                              AS `Class Group Name`,
    co.course_code                                       AS `Course Code`,
    co.course_name                                       AS `Course Name`,
    cct.name                                             AS `Component`,
    ft.term_name                                         AS `Term`,
    COALESCE(cfn.faculty_names, 'Not Assigned')          AS `Faculty Name`,
    ua.registration_id                                   AS `Student Registration ID`,
    TRIM(CONCAT(ua.f_name, ' ', COALESCE(ua.l_name, ''))) AS `Student Name`,
    COALESCE(crt.display_name, crt.name, 'Not Mapped')   AS `Enrollment Type`
FROM class c
JOIN filtered_terms ft            ON ft.term_id = c.term_id
LEFT JOIN course co               ON co.course_id = c.course_id
LEFT JOIN course_component_type cct ON cct.id = c.course_component_type_id
LEFT JOIN class_faculty_names cfn ON cfn.class_id = c.id
JOIN class_student cs             ON cs.class_id = c.id
LEFT JOIN user_attributes ua      ON ua.ukid = cs.ukid
LEFT JOIN ams_student_course asc1 ON asc1.ukid = cs.ukid
                                 AND asc1.course_id = c.course_id
                                 AND asc1.term_id = c.term_id
LEFT JOIN course_registration_type crt ON crt.id = asc1.course_registration_type_id
ORDER BY ft.term_name, co.course_code, c.batch, ua.registration_id;
