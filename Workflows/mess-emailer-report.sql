SELECT 
	t1.ukid, 
	CONCAT(ua.f_name, ' ', ua.l_name) AS Name, 
	ua.registration_id AS 'Registration ID', 
	a.email, 
	mm.name AS 'Mess Name', 
	SUM(CASE WHEN m.name = 'Breakfast' THEN t1.meal_availed_count ELSE 0 END) AS 'Breakfast', 
	SUM(CASE WHEN m.name = 'Lunch' THEN t1.meal_availed_count ELSE 0 END) AS 'Lunch', 
	SUM(CASE WHEN m.name in ('Evening Snacks','Snacks') THEN t1.meal_availed_count ELSE 0 END) AS 'Evening Snacks', 
	SUM(CASE WHEN m.name = 'Dinner' THEN t1.meal_availed_count ELSE 0 END) AS 'Dinner', 
	SUM(t1.meal_availed_count) AS total_meals, 
	YEAR(ms.date) AS year, MONTHNAME(ms.date) AS month, c.college_name AS school,
	concat(CAST(reg_code_abbrev AS CHAR CHARACTER SET utf8)," Monthly Meal Consumption Report for ",MONTHNAME(ms.date)," ",YEAR(ms.date)) as subject
FROM 
	user_mess_schedule t1 
	LEFT JOIN mess_schedule ms ON ms.id = t1.mess_schedule_id 
	LEFT JOIN meal m ON m.id = ms.meal_id 
	LEFT JOIN mess mm ON mm.id = ms.mess_id 
	LEFT JOIN user_attributes ua ON ua.ukid = t1.ukid 
	LEFT JOIN authenticator a ON a.ukid = ua.ukid 
	LEFT JOIN college c ON c.college_id = ua.college_id 
	WHERE ms.date BETWEEN '2025-01-01' AND '2025-05-31' 
	GROUP BY t1.ukid, mm.name 
	ORDER BY ms.date;

-- Version 2

SELECT 
  ms.date AS Date, 
--   t1.ukid, 
  CONCAT(ua.f_name, ' ', ua.l_name) AS Name, 
  ua.registration_id AS "Registration ID",  
--   t1.code AS "Availed Coupon", 
  DATE_ADD(
    DATE_ADD(t1.applied_on, INTERVAL 5 HOUR), 
    INTERVAL 30 MINUTE
  ) AS "Last Availed On", 
  mm.name AS "Mess Name", 
  m.name AS "Meal Name", 
  case 
	when a.email like 'veg%' then 'Veg'
	when a.email like 'nonveg%' then 'Non-Veg'
	else 'Sodexo'
  end as 'Meal Type',
--   a.email AS "Admin Account", 
--   t1.meal_availed_count AS "Coupons Used",
  ua.user_type
FROM 
  user_mess_schedule t1 
  LEFT JOIN mess_schedule ms ON ms.id = t1.mess_schedule_id 
  LEFT JOIN meal m ON m.id = ms.meal_id 
  LEFT JOIN mess mm ON mm.id = ms.mess_id 
  LEFT JOIN user_attributes ua ON ua.ukid = t1.ukid 
  LEFT JOIN authenticator a ON a.ukid = t1.applied_by
WHERE ms.date BETWEEN '2025-01-01' AND '2025-05-31'
ORDER BY 
  ms.date DESC;