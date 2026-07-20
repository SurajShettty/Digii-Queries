SELECT  
	ua.registration_id,
    a.email,
    CONCAT(ua.f_name, " ", ua.l_name) AS student_name,
    p.programme_name,
    d.department_name,
	gpl.in_entry AS in_punch,
    gpl.out_entry AS out_punch,
    gpl.pass_type,
    gpl.defaulter,
    gpl.defaulted_on,
    gps.status,
    im.name AS hostel_room,
    im2.name AS hostel_building,
    gplp.pass_start,
    gplp.pass_end
FROM gate_pass_log gpl
LEFT JOIN gate_pass_status gps ON gps.id = gpl.status_id
LEFT JOIN user_attributes ua ON ua.ukid = gpl.ukid
LEFT JOIN authenticator a ON a.ukid = gpl.ukid
LEFT JOIN student_profile sp ON sp.ukid = gpl.ukid
LEFT JOIN programme p ON p.programme_id = sp.programme_id
LEFT JOIN department d ON d.department_id = p.department_id
LEFT JOIN infrastructure_master im ON im.infrastructure_version_id = gpl.hostel_id 
LEFT JOIN infrastructure_master im2 ON im2.id = im.parent_id
LEFT JOIN gate_pass_long_pass gplp ON gplp.log_id = gpl.id
WHERE 
	(DATE(gpl.out_entry) >= "2025-09-01" OR DATE(gpl.out_entry) IS NULL)
	AND gpl.accommodation_type = "HOSTELLER";




-- UBS gate pass report
"""SELECT 
    ua.registration_id,
    CONCAT(ua.f_name, ' ', ua.l_name) name,
    gpl.*,
    gps.*
FROM
    gate_pass_log gpl
        LEFT JOIN
    gate_pass_status gps ON gps.id = gpl.status_id
        LEFT JOIN
    authenticator au ON au.ukid = gpl.ukid
        LEFT JOIN
    user_attributes ua ON ua.ukid = au.ukid
WHERE
    accommodation_type = 'HOSTELLER'
        AND missing_entry_reason IS NULL
        AND in_entry IS NULL
        AND ua.user_type = 'student'
        AND au.is_active = 1;"""