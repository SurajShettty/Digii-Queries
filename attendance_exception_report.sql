-- Attendance Exception Report (collpoll_university)
-- Grain: one row per exception REQUEST (attendance_exception_logs).
-- An "exception" = a student's attendance for a date/time range converted to a
-- leave/exception category (status_id -> UDC_09_USER_ATTENDANCE_STATUS), e.g.
-- Sports Leave, Event Leave, Medical Leave, On Duty, Present, Absent, etc.
-- applied_attendance_exception_log holds the individual lessons each request hit.

SELECT
  ael.id                                                       AS exception_id,
  ael.ukid                                                     AS student_ukid,
  TRIM(CONCAT_WS(' ', ua.f_name, " ", ua.l_name))        AS student_name,
  au.email                                                     AS student_email,
  sp.enrollment_number,
  ua.registration_id,
  uas.status                                                   AS exception_type,
  uas.abbreviation                                             AS exception_abbr,
  uas.final_status,
  uas.do_not_consider_for_attendance,
  DATE(ael.start_date)                                         AS start_date,
  DATE(ael.end_date)                                           AS end_date,
  ael.is_entire_day,
  ael.start_time,
  ael.end_time,
  t.name                                                       AS term_name,
  DATE(ael.applied_on)                                         AS applied_on,
  ael.performed_by_ukid,
  COALESCE(
    NULLIF(TRIM(CONCAT_WS(' ', fp.f_name,  fp.m_name,  fp.l_name)),  ''),
    NULLIF(TRIM(CONCAT_WS(' ', ap.f_name,  ap.m_name,  ap.l_name)),  ''),
    NULLIF(TRIM(CONCAT_WS(' ', psp.f_name, psp.m_name, psp.l_name)), '')
  )                                                            AS applied_by,
  ael.remark,
  COUNT(aael.id)                                               AS lessons_affected,
  SUM(aael.exception_status = 'APPLICABLE')                    AS lessons_applicable
FROM attendance_exception_logs ael
LEFT JOIN student_profile sp                ON sp.ukid  = ael.ukid
LEFT JOIN user_attributes ua                ON sp.ukid  = ua.ukid
LEFT JOIN authenticator au                  ON au.ukid  = ael.ukid
LEFT JOIN faculty_profile fp                ON fp.ukid  = ael.performed_by_ukid
LEFT JOIN admin_profile ap                  ON ap.ukid  = ael.performed_by_ukid
LEFT JOIN student_profile psp               ON psp.ukid = ael.performed_by_ukid
LEFT JOIN UDC_09_USER_ATTENDANCE_STATUS uas ON uas.id   = ael.status_id
LEFT JOIN term t                            ON t.id     = ael.term_id
LEFT JOIN applied_attendance_exception_log aael
       ON aael.attendance_exception_log_id  = ael.id
-- Optional filters for analytics:
--   WHERE ael.term_id = <term_id>
--   AND   ael.applied_on >= '2025-01-01'
GROUP BY ael.id
ORDER BY ael.applied_on DESC;
