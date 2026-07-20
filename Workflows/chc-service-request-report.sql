SELECT 
    chcr.service_id AS 'Service Id',
    cs.title AS 'Service Name',
    chcr.id AS 'Request Id',
--     chcr.ukid AS 'Request Raised By',
    ua.registration_id AS  'Request Raised By (Registration_id)',
    CONCAT(ua.f_name, " ", ua.l_name) AS 'Request Raised By (Name)',
--     chcwcm.ukid AS 'Approver',
    ua2.registration_id AS 'Approver (Registration_id)',
    CONCAT(ua2.f_name, " ", ua2.l_name) AS 'Approver (Name)',
    chcr.status,
--     er.request_id,
    er.from_date AS 'Leave From Date',
    er.to_date AS 'Leave To Date',
    er.reason_for_leave_or_wfh AS 'Reason for Leave / WFH',
    er.no_of_days AS 'No. Of Days',
    er.leave_adjustments AS 'Leave Adjustments',er.type_of_leave as 'Type of Leave'
FROM chc_request chcr
LEFT JOIN chc_work_centre_member chcwcm ON chcwcm.work_centre_id = chcr.work_centre_id
LEFT JOIN user_attributes ua ON ua.ukid = chcr.ukid 
LEFT JOIN user_attributes ua2 ON ua2.ukid = chcwcm.ukid
LEFT JOIN chc_service cs ON cs.id = chcr.service_id 
LEFT JOIN (
    SELECT 
        t1.request_id,
        MAX(CASE WHEN t2.name in ("From Date") THEN t1.value END) AS from_date, 
        MAX(CASE WHEN t2.name in ("To Date") THEN t1.value END) AS to_date,
        MAX(CASE WHEN t2.name in ("Reason for Leave", "Reason for WFH") THEN t1.value END) AS reason_for_leave_or_wfh,
        MAX(CASE WHEN t2.name in ("No of days") THEN t1.value END) AS no_of_days,
        MAX(CASE WHEN t2.name in ("Leave Adjustment") THEN t1.value END) AS leave_adjustments,
        MAX(CASE WHEN t2.name in ('Type of Leave','Type of leave') THEN ex.label END) AS type_of_leave
    FROM 
        chc_request_form_field_value t1
        LEFT JOIN chc_request_form_field t2 ON t2.id = t1.field_id
        LEFT JOIN chc_request_form t3 ON t3.id = t2.form_id
        left join 
        (
        	select 
        		t2.id as field_id,
        		t3.id,
        		t3.label 
        	from  
        		chc_request_form_field t2 
        		left join chc_request_form_field_element_option t3 on t3.field_id = t2.id where t2.name in ('Type of Leave','Type of leave')
        ) ex on ex.id = t1.value
    GROUP BY t1.request_id
) AS er ON er.request_id = chcr.id
WHERE 
    chcr.service_id in (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,58)
    AND er.from_date BETWEEN '2023-01-01' AND '2024-12-31';