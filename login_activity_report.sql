-- Module: Analytics Dashboard — Login Activity (per user)
-- One row per user with their last login, recency, rolling login counts
-- (7/30/90-day and all-time), and their most-used device.
--
-- Schema:
--   user_attributes (ua) -> ukid, college_id (tenant), university_id
--   login_details   (ld) -> ukid, timestamp (login time), success, device_type ('BROWSER'/'APP')
--
-- Notes:
--   ld.success = 1 -> only successful logins are counted (failed attempts excluded).
--   login_count_* windows are relative to CURDATE() at query run time.
--   primary_device = whichever of APP/BROWSER has more successful logins for that
--   user; ties go to APP (swap the CASE branches to prefer BROWSER instead). NULL
--   if the user has never logged in, or has logins with no device_type recorded.
--   Users with zero logins still appear (LEFT JOIN) with NULL last_login_date and
--   0 counts, matching users who exist but have never signed in.
--   The inner "ukid IN (...)" semi-join scopes login_details to this tenant's
--   users before aggregating — a no-op here (this DB holds a single college) but
--   keeps the aggregation cheap if ever pointed at a multi-tenant login_details.
--   Change/remove ua.college_id filter to scope to a specific tenant, or drop it
--   (and the semi-join) entirely if this database only ever holds a single
--   institution.
--
-- Optimised from the original two-subquery version: that scanned/grouped
-- login_details twice (once for the rolling counts, once via a ROW_NUMBER()
-- window function to rank device_type per user). Since device_type only ever
-- takes two values, both are folded into a single grouped pass with conditional
-- SUM(), halving the work done against login_details.

SELECT
    ua.ukid,
    ua.college_id AS tenant_id,
    ls.last_login_date,
    DATEDIFF(CURDATE(), ls.last_login_date) AS days_since_last_login,
    COALESCE(ls.login_count_7d, 0)  AS login_count_7d,
    COALESCE(ls.login_count_30d, 0) AS login_count_30d,
    COALESCE(ls.login_count_90d, 0) AS login_count_90d,
    COALESCE(ls.login_count_all_time, 0) AS login_count_all_time,
    CASE
        WHEN COALESCE(ls.app_count, 0) = 0 AND COALESCE(ls.browser_count, 0) = 0 THEN NULL
        WHEN ls.app_count >= ls.browser_count THEN 'APP'
        ELSE 'BROWSER'
    END AS primary_device
FROM user_attributes ua
LEFT JOIN (
    SELECT
        ukid,
        MAX(timestamp) AS last_login_date,
        SUM(timestamp >= DATE_SUB(CURDATE(), INTERVAL 7 DAY))  AS login_count_7d,
        SUM(timestamp >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)) AS login_count_30d,
        SUM(timestamp >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)) AS login_count_90d,
        COUNT(*) AS login_count_all_time,
        SUM(device_type = 'APP')     AS app_count,
        SUM(device_type = 'BROWSER') AS browser_count
    FROM login_details
    WHERE success = 1
      AND ukid IN (SELECT ukid FROM user_attributes WHERE college_id = 504)
    GROUP BY ukid
) ls ON ls.ukid = ua.ukid
WHERE ua.college_id = 504 -- JSPM University Pune; adjust/remove as needed
ORDER BY ua.ukid;
