SELECT a.ukid, CONCAT(ua.f_name," ",ua.l_name) AS "Student Name", a.email AS Email, ua.registration_id AS "Registration ID", sp.year_of_joining AS "Batch",p.duration,(sp.year_of_joining + p.duration) AS pass_out_year,q.name AS "Quota", p.programme_name AS "Programme", d.department_name AS "Department", UPPER(sp.gender) AS Gender,sp.accommodation_type,if(a.is_active=1,"Active","Inactive") AS STATUS,pss.name AS placement_reg_status,psc.signed
FROM authenticator a
LEFT JOIN user_attributes ua ON a.ukid = ua.ukid
LEFT JOIN student_profile sp ON a.ukid = sp.ukid
LEFT JOIN programme p ON sp.programme_id = p.programme_id
LEFT JOIN quota q ON q.id = sp.quota_id
LEFT JOIN department d ON sp.department_id = d.department_id
LEFT JOIN (
SELECT j.*,t1.student_ukid
FROM placement_student_status t1 CROSS
JOIN JSON_TABLE(placement_cycle_log, '$[*]' COLUMNS (
 placementCycleId VARCHAR(100) PATH '$.placementCycleId', 
 registrationStatusId VARCHAR(100) PATH '$.registrationStatusId'
)
) AS j
WHERE placementCycleId = 4) ex ON ex.student_ukid = ua.ukid
LEFT JOIN placement_status pss ON pss.id = ex.registrationStatusId
LEFT JOIN placement_student_consent psc ON psc.student_ukid = ex.student_ukid
WHERE ua.user_type IN ("student") AND a.is_active = 1 AND pss.name IS NOT NULL;