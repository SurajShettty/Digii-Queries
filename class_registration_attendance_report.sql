WITH filtered_terms AS (
    SELECT
        id AS term_id,
        name AS term_name
    FROM term
    WHERE
        (starts <= CURRENT_DATE AND ends >= CURRENT_DATE)
        OR (ends < CURRENT_DATE AND ends >= CURRENT_DATE - INTERVAL '30' DAY)
),
valid_classes AS (
    SELECT c.id AS class_id, ft.term_name, ft.term_id, t3.course_id, cv.id as course_version_id, c.batch, tt.name AS type, tc.id AS term_course_id, c.created_timestamp AS class_created_timestamp
    FROM class c
    LEFT JOIN course_component_type tt on tt.id = c.course_component_type_id
    INNER JOIN filtered_terms ft ON c.term_id = ft.term_id
    INNER JOIN term_course tc ON tc.term_id = ft.term_id AND tc.course_id = c.course_id
    LEFT JOIN course_version cv ON tc.course_version_id = cv.id
    LEFT JOIN course t3 ON cv.course_id = t3.course_id
),
attendance_summary AS (
    SELECT
        ca.ukid,
        ca.class_id,
        COUNT(*) AS total_sessions,
        SUM(CASE WHEN ast.code = 'P' THEN 1 ELSE 0 END) AS total_present
    FROM class_attendance ca
    LEFT JOIN attendance_status ast ON ast.id = ca.status_id
    GROUP BY ca.ukid, ca.class_id
)
SELECT
    cs.ukid,
    cs.class_id,
    vc.term_id,
    vc.term_name,
    vc.course_id,
    vc.term_course_id,
    vc.batch AS class_name,
    vc.type AS class_type,
    c.course_code,
    cv.course_name,
    d.department_id AS course_department_id,
    d.department_name AS course_dept,
    COALESCE(d.alt_name, d.department_name) as department_alt_name,
    vc.class_created_timestamp,
    COALESCE(asum.total_sessions, 0) AS total_sessions,
    COALESCE(asum.total_present, 0) AS total_present
FROM valid_classes vc
INNER JOIN class_student cs ON cs.class_id = vc.class_id
LEFT JOIN course_version cv on cv.id = vc.course_version_id
LEFT JOIN course c ON c.course_id = vc.course_id
LEFT JOIN department d ON d.department_id = c.department_id
LEFT JOIN attendance_summary asum ON asum.ukid = cs.ukid AND asum.class_id = cs.class_id;
