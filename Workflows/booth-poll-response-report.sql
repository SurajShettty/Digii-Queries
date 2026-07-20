-- Pivoted report
SELECT
    t3.registration_id,
    CONCAT(t3.f_name, ' ', t3.l_name) AS Name,
    t5.email,
    t5.phone,
    t7.programme_name,
    t6.gender,
    t4.booth_name,
    response_time,
    max(case when t2.question_content = 'Select your stream' then t1.response_content end) as 'Select your stream',
    max(case when t2.question_content = 'Choose one Value Added Course form the options below.' then t1.response_content end) as 'Choose one Value Added Course form the options below.'
FROM
    response t1 left
        JOIN
    question t2 ON t2.question_id = t1.question_id left
        JOIN
    user_attributes t3 ON t3.ukid = t1.ukid left
        JOIN
    authenticator t5 ON t5.ukid = t3.ukid left
        JOIN
    student_profile t6 ON t6.ukid = t3.ukid left
        JOIN
    programme t7 ON t7.programme_id = t6.programme_id left
        JOIN
    booth t4 ON t4.booth_id = t1.booth_id
WHERE
    t4.booth_id IN (2739)
    group by t4.booth_id,t1.ukid;


-- Not Pivoted report
SELECT
    t3.registration_id,
    CONCAT(t3.f_name, ' ', t3.l_name) AS Name,
    t5.email,
    t5.phone,
    t7.programme_name,
    t8.name,
    t6.gender,
    t4.booth_name,
    t2.question_content,
    t1.response_content,
    response_time
FROM
    response t1 left
        JOIN
    question t2 ON t2.question_id = t1.question_id left
        JOIN
    user_attributes t3 ON t3.ukid = t1.ukid left
        JOIN
    authenticator t5 ON t5.ukid = t3.ukid left
        JOIN
    student_profile t6 ON t6.ukid = t3.ukid left
        JOIN
    programme t7 ON t7.programme_id = t6.programme_id left
        JOIN
    specialisation t8 ON t8.id = t6.specialisation_id left
        JOIN
    booth t4 ON t4.booth_id = t1.booth_id
WHERE
    t4.booth_id IN (2739);