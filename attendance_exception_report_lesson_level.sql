-- Attendance Exception Report — LESSON LEVEL (collpoll_university)
-- Grain: one row per affected lesson (applied_attendance_exception_log).
-- Each row = a single lesson whose attendance was touched by an exception request.
--   previous_status  = what the lesson's attendance was BEFORE the exception
--   exception_type   = the category it was converted TO (from the parent request)
--   exception_status = APPLICABLE (actually applied) vs NOT_APPLICABLE (skipped)
--
-- NOTE: columns from `lesson` and `class` (course name, lesson date/time) are NOT
-- yet verified — the MySQL MCP connection dropped before I could inspect them.
-- The block below runs as-is on verified columns; uncomment the lesson/class
-- joins + selects after confirming their column names.

SELECT
  aael.id                                                AS applied_log_id,
  aael.attendance_exception_log_id                       AS exception_id,
  aael.ukid                                              AS student_ukid,
  TRIM(CONCAT_WS(' ', ua.f_name, " ", ua.l_name))        AS student_name,
  au.email                                               AS student_email,
  ua.registration_id,

  aael.class_id,
  aael.lesson_id,
  -- les.lesson_date,            -- TODO: verify column name in `lesson`
  -- les.start_time AS lesson_start_time,
  -- cls.name       AS class_name,   -- TODO: verify column name in `class`

  prev.status        AS previous_status,        -- attendance before exception
  prev.abbreviation  AS previous_abbr,
  uas.status         AS exception_type,          -- category applied (from request)
  uas.abbreviation   AS exception_abbr,
  uas.final_status,
  uas.do_not_consider_for_attendance,

  aael.exception_status,                          -- APPLICABLE / NOT_APPLICABLE
  aael.attendance_percent,
  aael.previously_marked_from,
  aael.reason,

  t.name             AS term_name,
  DATE(ael.start_date) AS request_start_date,
  DATE(ael.end_date)   AS request_end_date,
  DATE(ael.applied_on) AS applied_on,
  ael.performed_by_ukid,
  COALESCE(
    NULLIF(TRIM(CONCAT_WS(' ', fp.f_name,  fp.m_name,  fp.l_name)),  ''),
    NULLIF(TRIM(CONCAT_WS(' ', ap.f_name,  ap.m_name,  ap.l_name)),  ''),
    NULLIF(TRIM(CONCAT_WS(' ', psp.f_name, psp.m_name, psp.l_name)), '')
  )                  AS applied_by,
  aael.created_timestamp
FROM applied_attendance_exception_log aael
JOIN      attendance_exception_logs ael       ON ael.id  = aael.attendance_exception_log_id
LEFT JOIN student_profile sp                  ON sp.ukid = aael.ukid
LEFT JOIN user_attributes ua                ON sp.ukid  = ua.ukid
LEFT JOIN authenticator au                    ON au.ukid = aael.ukid
LEFT JOIN UDC_09_USER_ATTENDANCE_STATUS prev  ON prev.id = aael.previous_status_id
LEFT JOIN UDC_09_USER_ATTENDANCE_STATUS uas   ON uas.id  = ael.status_id
LEFT JOIN term t                              ON t.id    = ael.term_id
LEFT JOIN faculty_profile fp                  ON fp.ukid = ael.performed_by_ukid
LEFT JOIN admin_profile ap                    ON ap.ukid = ael.performed_by_ukid
LEFT JOIN student_profile psp                 ON psp.ukid= ael.performed_by_ukid
-- LEFT JOIN lesson les                       ON les.id  = aael.lesson_id    -- enrich after verifying
-- LEFT JOIN class  cls                       ON cls.id  = aael.class_id     -- enrich after verifying
-- Optional filters:
--   WHERE aael.exception_status = 'APPLICABLE'
--   AND   ael.term_id = <term_id>
ORDER BY aael.attendance_exception_log_id DESC, aael.id;
