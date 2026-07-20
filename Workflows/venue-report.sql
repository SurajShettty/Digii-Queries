SELECT 
  ib.start AS 'event start', 
  ib.end AS 'event end', 
  i.name AS 'Venue Room', 
  i.type AS 'Type', 
  CONCAT(
    ua.f_name, ' ', ua.m_name, ' ', ua.l_name
  ) AS 'Requested by', 
  ua.user_type AS 'RequestorUserType', 
  d.department_name AS 'Department', 
  CONCAT(
    ua2.f_name, ' ', ua2.m_name, ' ', ua2.l_name
  ) AS 'BookedFor', 
  ib.purpose AS 'Purpose', 
  ibdr.requirement AS 'Facilities', 
  ib.status AS 'Status', 
  CONCAT(
    ua3.f_name, ' ', ua3.m_name, ' ', ua3.l_name
  ) AS 'Admin', 
  CONCAT(
    ua4.f_name, ' ', ua4.m_name, ' ', ua4.l_name
  ) AS 'Cancelled by', 
  ib.status_reason AS 'Reason for Decline' 
FROM 
  infrastructure_booking ib 
  LEFT JOIN user_attributes ua ON ua.ukid = ib.booked_by 
  LEFT JOIN user_attributes ua2 ON ua2.ukid = ib.booked_for_ukid 
  LEFT JOIN user_attributes ua3 ON ua3.ukid = ib.admin_ukid 
  LEFT JOIN user_attributes ua4 ON ua4.ukid = ib.cancelled_by 
  LEFT JOIN infrastructure i ON i.id = ib.infrastructure_id 
  LEFT JOIN infrastructure_booking_department_requirement ibdr ON ib.id = ibdr.booking_id 
  LEFT JOIN department d ON d.department_id = ibdr.department_id;




--version 2
SELECT 
  ib.id AS 'Booking Id',
  i.name AS 'Venue', 
  -- it.type AS "Infrastructure Type", 
  Concat (ua.f_name, " ", ua.l_name) AS 'Booked By', 
  Concat (ua2.f_name, " ", ua2.l_name) AS 'Booked For', 
  -- Coalesce(i.capacity, 0) AS capacity, 
  ib.purpose AS 'Purpose', 
  -- ib.additional_requirements, 
  IF (
    ib.start > Current_timestamp() 
    AND ib.END > Current_timestamp(), 
    'Booked', 
    'Available'
  ) AS 'Availability', 
  DATE(ib.start) AS "Start Date", 
  DATE(ib.END) AS 'End Date',
  TIME(ib.start) AS "Start Time", 
  TIME(ib.END) AS 'End Time',
  -- Week(ib.start) week, 
  -- Month(ib.start) month, 
  Round((SUM(Timestampdiff(minute, ib.start, ib.END)) / 60), 1) AS 'Booking Hours'
  -- Coalesce(ib.status, 'Direct Approved') AS STATUS, 
  -- Convert_tz(Now(), '+00:00', '+05:30') AS 'Refreshed at' 
FROM 
  infrastructure_booking ib 
  left join infrastructure_version i ON i.id = ib.infrastructure_id 
  left join infrastructure_type it  ON it.id = i.type_id 
  left join user_attributes ua ON ua.ukid = ib.booked_by 
  left join user_attributes ua2 ON ua2.ukid = ib.booked_for_ukid 
WHERE 
  ib.is_cancelled = 0 AND YEAR(ib.start) = "2025"
GROUP BY 
  ib.id
ORDER BY ib.id desc;
