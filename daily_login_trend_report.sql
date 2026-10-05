-- Module: Analytics Dashboard — Daily Login Trend
-- One row per calendar date (per institution) with total successful logins,
-- split into app vs. browser logins.
--
-- Schema:
--   login_details   (ld) -> ukid, timestamp (login time), success, device_type ('BROWSER'/'APP')
--   user_attributes (ua) -> ukid, college_id (tenant)
--   college         (c)  -> college_id, college_name
--
-- Notes:
--   ld.success = 1 -> only successful logins are counted (failed attempts excluded).
--   date is DATE(ld.timestamp) in the database's stored timezone.
--   Uncomment the date range filter to limit the trend window (e.g. last 90 days).

SELECT
    DATE(ld.timestamp) AS `date`,
    ua.college_id AS tenant_id,
    c.college_name AS institution_name,
    COUNT(*) AS login_count,
    SUM(ld.device_type = 'APP')     AS app_logins,
    SUM(ld.device_type = 'BROWSER') AS browser_logins
FROM login_details ld
LEFT JOIN user_attributes ua ON ua.ukid = ld.ukid
LEFT JOIN college c ON c.college_id = ua.college_id
WHERE ld.success = 1
-- AND ld.timestamp >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
GROUP BY DATE(ld.timestamp), ua.college_id, c.college_name
ORDER BY `date`, tenant_id;
