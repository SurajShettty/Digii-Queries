-- Module: Analytics Dashboard — Peak Login Hours (last 7 days)
-- One row per institution / hour-of-day with the average number of successful
-- logins that occur in that hour, averaged across the last 7 days. Used to
-- plot a 24-hour login-activity curve per tenant.
--
-- Schema:
--   login_details   (ld) -> ukid, timestamp (login time), success
--   user_attributes (ua) -> ukid, college_id (tenant)
--   college         (c)  -> college_id, college_name
--
-- Notes:
--   ld.success = 1 -> only successful logins are counted (failed attempts excluded).
--   Window = ld.timestamp >= CURDATE() - 7 days; change the INTERVAL to widen/narrow it.
--   avg_logins = (total logins in that hour over the window) / (total distinct
--   calendar days with any successful login for that tenant in the window) —
--   the denominator is the same across all hours for a given tenant, so
--   naturally quiet hours (e.g. 2 AM) aren't inflated by only being divided by
--   the few days that happened to have activity at that specific hour.
--   Hours with zero logins in the window simply don't appear as rows.
--   `hour` is HOUR(ld.timestamp) in the database's stored timezone (0-23).

SELECT
    ua.college_id AS tenant_id,
    c.college_name AS institution_name,
    HOUR(ld.timestamp) AS `hour`,
    ROUND(COUNT(*) / td.total_days, 2) AS avg_logins
FROM login_details ld
JOIN user_attributes ua ON ua.ukid = ld.ukid
JOIN college c ON c.college_id = ua.college_id
JOIN (
    SELECT ua2.college_id AS tenant_id, COUNT(DISTINCT DATE(ld2.timestamp)) AS total_days
    FROM login_details ld2
    JOIN user_attributes ua2 ON ua2.ukid = ld2.ukid
    WHERE ld2.success = 1
      AND ld2.timestamp >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    GROUP BY ua2.college_id
) td ON td.tenant_id = ua.college_id
WHERE ld.success = 1
  AND ld.timestamp >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY ua.college_id, c.college_name, HOUR(ld.timestamp), td.total_days
ORDER BY tenant_id, `hour`;
