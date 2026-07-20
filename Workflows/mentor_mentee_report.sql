SELECT 
  ua2.ukid AS mentor_ukid, 
  ua2.registration_id AS mentor_reg_id, 
  CONCAT(ua2.f_name, ' ', ua2.l_name) AS mentor_name, 
  a2.email AS mentor_email, 
  a2.phone AS mentor_phone, 
  d.department_name mentor_dept_name, 
  ua.ukid AS mentee_ukid, 
  ua.registration_id AS mentee_reg_id, 
  CONCAT(ua.f_name, ' ', ua.l_name) AS mentee_name, 
  a.email AS mentee_email, 
  a.phone AS mentee_phone, 
  p.programme_name, 
  d2.department_name mentee_dept_name 
FROM 
  mentor_mapping m 
  LEFT JOIN user_attributes ua ON ua.ukid = m.mentee_ukid 
  LEFT JOIN user_attributes ua2 ON ua2.ukid = m.mentor_ukid 
  LEFT JOIN authenticator a ON a.ukid = ua.ukid 
  LEFT JOIN authenticator a2 ON a2.ukid = ua2.ukid 
  LEFT JOIN faculty_profile fp ON fp.ukid = ua2.ukid 
  LEFT JOIN department d ON d.department_id = fp.department_id 
  LEFT JOIN student_profile sp ON sp.ukid = ua.ukid 
  LEFT JOIN department d2 ON d2.department_id = sp.department_id 
  LEFT JOIN programme p ON p.programme_id = sp.programme_id 
ORDER BY 
  ua2.ukid
