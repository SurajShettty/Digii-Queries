SELECT
    t1.request_id,
    t1.assignee_ukid,
    cs.title as service_name,
    cs.id AS service_id,
    cr.status AS ticket_status,
    cr.created_on AS ticket_created_on,
    cw.title AS work_center_name,
    CONCAT(ua.f_name, ' ', ua.l_name) AS assignee_name,
    ua.registration_id AS assignee_id,
    ROUND((csc.time / 60)) AS time_in_hours,
    t1.type,
    t1.created_timestamp AS escalated_timestamp,
    CASE WHEN cr.status in ('closed','submitted') THEN ex.taken_by ELSE '-' END AS last_action_taken_by,
    CASE WHEN cr.status in ('closed','submitted') THEN ex.action_type ELSE '-' END AS last_action_type,
    ex.created_on last_action_time,
    fv.Name,fv.
    fv.Reg_id,
    fv.phone,fv.hostel_building,fv.Apartment as 'Apartment/Department No.',fv.val1 as 'If location is any common area, please specify',fv.type as issue_type,fv.Description,
    CONCAT(ua2.f_name, ' ', ua2.l_name) AS requestor,
    ua2.registration_id AS action_form_value_by,
    ex1.action_form,ex1.value as action_form_value
FROM
    chc_request_escalation_log t1
        LEFT JOIN
    chc_service_escalation csc ON csc.id = t1.service_escalation_id
        LEFT JOIN
    chc_request cr ON cr.id = t1.request_id
        LEFT JOIN
    chc_service cs ON cs.id = cr.service_id
        LEFT JOIN
    user_attributes ua ON ua.ukid = csc.assignee_ukid
        LEFT JOIN
    chc_work_centre cw ON cw.id = t1.work_centre_id
    left join (SELECT request_id,
           action_type,
           taken_by,created_on
    FROM (
        SELECT
            cwcra.request_id,
            cwca.action_taken_name AS action_type,
            COALESCE(CONCAT(ua3.f_name, ' ', ua3.l_name), 'System') AS taken_by,
            ROW_NUMBER() OVER (
                PARTITION BY cwcra.request_id
                ORDER BY cwcra.created_on DESC
            ) AS rn,cwcra.created_on
        FROM chc_work_centre_request_action cwcra
        JOIN chc_work_centre_action cwca
            ON cwca.id = cwcra.action_id
        LEFT JOIN user_attributes ua3
            ON ua3.ukid = cwcra.taken_by_ukid  
    ) t
    WHERE rn = 1) ex on ex.request_id = t1.request_id
    left join (
 SELECT
        cr.id as request_id,
        MAX(CASE WHEN crff.name IN ('Name') THEN crfv.value END) AS Name,
        MAX(CASE WHEN crff.name IN ('Registration Id') THEN crfv.value END) AS Reg_id,
       MAX(CASE WHEN crff.name IN ('Phone') THEN crfv.value END) AS phone,
        MAX(CASE WHEN crff.name IN ('Hostel/Building name') THEN crfv.value END) AS hostel_building,
        MAX(CASE WHEN crff.name IN ('Apartment/Department No.','Appartment/Department No') THEN crfv.value END) AS Apartment,
        MAX(CASE WHEN crff.name IN ('If location is any common area, please specify') THEN crfv.value END) AS val1,
         MAX(CASE WHEN crff.name IN ('Issue Type') and crff.element = 'dropdown' THEN coalesce(t4.label,crfv.value_reference) END) AS type,
        MAX(CASE WHEN crff.name IN ('Description') THEN crfv.value END) AS Description
    FROM chc_request cr
    LEFT JOIN chc_request_form_field_value crfv ON crfv.request_id = cr.id
    LEFT JOIN chc_request_form_field crff ON crff.id = crfv.field_id
    left join chc_request_form_field_element_option t4 on t4.id = crfv.value
    GROUP BY cr.id
) fv on fv.request_id = t1.request_id
left join (select t1.request_id,t1.ukid,t3.title as action_form,t4.work_centre_id,t4.id as action_id,t1.value from chc_work_centre_form_field_value t1 left join chc_work_centre_form_field t2 on t2.id = t1.field_id left join chc_work_centre_form t3 on t3.id = t2.form_id left join chc_work_centre_action t4 on t4.id = t3.action_id left join chc_work_centre t5 on t5.id = t4.work_centre_id) ex1 on ex1.request_id = t1.request_id
LEFT JOIN
    user_attributes ua2 ON ua2.ukid = ex1.ukid
WHERE
    csc.service_id in (7,
8,
9,
10,
11,
12,
13,
14,
15,
16,
17)
ORDER BY cr.id , csc.service_id , ROUND((csc.time / 60));