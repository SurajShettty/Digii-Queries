-- PASSOUT YEAR

SELECT
    sp.ukid,
    ua.registration_id AS "Registration ID",
    CONCAT(ua.f_name, ' ', ua.l_name) AS Name,
    p.programme_name Programme,
    d.department_name Department,
    p.duration Duration,
    sp.year_of_joining Batch,
    sp.year_of_joining + p.duration AS "Passout year"
FROM
    student_profile sp
    LEFT JOIN user_attributes ua ON ua.ukid = sp.ukid
    LEFT JOIN authenticator a ON a.ukid=sp.ukid
    LEFT JOIN programme p ON p.programme_id = sp.programme_id
    LEFT JOIN department d ON d.department_id=p.department_id
WHERE
    a.is_active=1 
    AND
    ua.user_type='student' 
    AND
    sp.year_of_joining + p.duration IN ();
