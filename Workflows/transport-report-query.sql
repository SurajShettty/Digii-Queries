SELECT
	ta.ukid,
    ua.registration_id, 
    CONCAT(ua.f_name, ' ',ua.l_name) AS 'Name',
    programme_name,
    tr.name AS 'route',
    tpp.name AS 'pickup_point',
    a.email,
    ta.status,
    ex.due_amount,
    ex.paid_amount,
    ex.pending_amount 
FROM 
    transport_allotment ta 
    LEFT JOIN user_attributes ua ON ua.ukid = ta.ukid 
    LEFT JOIN student_profile sp ON sp.ukid = ua.ukid 
    LEFT JOIN programme p ON p.programme_id = sp.programme_id 
    LEFT JOIN transport_route_pickup_point trp on trp.id = ta.option_id 
    LEFT JOIN transport_route tr ON tr.id = trp.route_id 
    LEFT JOIN transport_pickup_point tpp ON tpp.id = trp.pickup_point_id 
    LEFT JOIN authenticator a ON a.ukid = ta.ukid 
    LEFT JOIN 
    (
        SELECT 
            dues_id,
            student_ukid,
            due_amount,
            paid_amount,
            pending_amount 
        FROM 
            dues_v2 d 
            LEFT JOIN dues_finance_v2 df ON df.dues_id = d.id 
        WHERE 
            entity = 'TRANSPORT_MANAGEMENT'
    ) ex ON ex.student_ukid = ta.ukid AND ex.dues_id = ta.due_id;