-- Student Lesson Attendance — Current vs Previous Status (collpoll_university)
-- Grain: one row per student per lesson (class_attendance).
-- Source of history: attendance_edit_log, which logs EVERY marking of a student's
-- lesson attendance (first mark, faculty re-mark, biometric, bulk upload, default
-- attendance, exception). The latest log row always equals class_attendance.status_id,
-- so the "previous status" is the log row immediately before the latest one.
--   previous_status   = NULL when attendance was marked only once (never changed)
--   times_marked      = total number of times the lesson attendance was saved
--   status_changed    = Yes only if previous status differs from current
-- Note: a re-save with the same status also creates a log row, so previous_status can
-- equal current_status. Use the "last DIFFERENT status" variant at the bottom if needed.
-- Timestamps in DB are UTC; converted to IST below.

WITH edit_hist AS (
    SELECT
        e.ukid,
        e.lesson_id,
        e.status_id,
        e.modified_by,
        e.updated_time,
        e.attendance_marked_from,
        ROW_NUMBER() OVER w                                   AS rn_desc,
        COUNT(*)     OVER (PARTITION BY e.ukid, e.lesson_id)  AS times_marked
    FROM attendance_edit_log e
    WINDOW w AS (PARTITION BY e.ukid, e.lesson_id ORDER BY e.updated_time DESC, e.id DESC)
),
cur_log  AS (SELECT * FROM edit_hist WHERE rn_desc = 1),
prev_log AS (SELECT * FROM edit_hist WHERE rn_desc = 2)
SELECT
    ca.ukid,
    ua.registration_id,
    CONCAT(ua.f_name, ' ', ua.l_name)                        AS student_name,
    cc.course_code,
    cc.course_name,
    c.batch                                                  AS class,
    ca.lesson_id,
    DATE(l.start)                                            AS lesson_date,
    l.start                                                  AS lesson_start,
    l.end                                                    AS lesson_end,

    cur.status                                               AS current_status,
    cur.final_status                                         AS current_final_status,
    COALESCE(ca.attendance_marked_from, cl.attendance_marked_from) AS current_marked_from,
    CONCAT(cm.f_name, ' ', cm.l_name)                        AS current_marked_by,
    CONVERT_TZ(cl.updated_time, '+00:00', '+05:30')          AS current_marked_at_ist,

    pst.status                                               AS previous_status,
    pst.final_status                                         AS previous_final_status,
    pl.attendance_marked_from                                AS previous_marked_from,
    CONCAT(pm.f_name, ' ', pm.l_name)                        AS previous_marked_by,
    CONVERT_TZ(pl.updated_time, '+00:00', '+05:30')          AS previous_marked_at_ist,

    cl.times_marked,
    CASE WHEN pl.status_id IS NOT NULL AND pl.status_id <> ca.status_id
         THEN 'Yes' ELSE 'No' END                            AS status_changed
FROM class_attendance ca
LEFT JOIN cur_log  cl                         ON cl.ukid = ca.ukid AND cl.lesson_id = ca.lesson_id
LEFT JOIN prev_log pl                         ON pl.ukid = ca.ukid AND pl.lesson_id = ca.lesson_id
LEFT JOIN UDC_09_USER_ATTENDANCE_STATUS cur   ON cur.id = ca.status_id
LEFT JOIN UDC_09_USER_ATTENDANCE_STATUS pst   ON pst.id = pl.status_id
LEFT JOIN user_attributes cm                  ON cm.ukid = cl.modified_by
LEFT JOIN user_attributes pm                  ON pm.ukid = pl.modified_by
LEFT JOIN lesson l                            ON l.id = ca.lesson_id
LEFT JOIN class c                             ON c.id = ca.class_id
LEFT JOIN course cc                           ON cc.course_id = c.course_id
LEFT JOIN user_attributes ua                  ON ua.ukid = ca.ukid
WHERE 1 = 1
  -- AND ca.ukid = 392841                     -- a specific student
  -- AND ca.lesson_id = 25416                 -- a specific lesson
  -- AND DATE(l.start) BETWEEN '2026-09-01' AND '2026-09-30'
  AND pl.status_id <> ca.status_id            -- only lessons whose status actually changed (remove to see all)
ORDER BY l.start, ua.registration_id;


-- Variant: last DIFFERENT status before the current one (ignores same-status re-saves)
-- Replace prev_log above with:
-- prev_log AS (
--     SELECT * FROM (
--         SELECT h.*, ROW_NUMBER() OVER (PARTITION BY h.ukid, h.lesson_id ORDER BY h.rn_desc) AS rn_diff
--         FROM edit_hist h
--         JOIN cur_log c ON c.ukid = h.ukid AND c.lesson_id = h.lesson_id
--         WHERE h.status_id <> c.status_id
--     ) d WHERE d.rn_diff = 1
-- )


-- Full history: every marking of one student's lesson, oldest first
-- SELECT e.id, e.ukid, e.lesson_id, s.status, e.attendance_marked_from,
--        CONCAT(ua.f_name,' ',ua.l_name) AS marked_by,
--        CONVERT_TZ(e.updated_time,'+00:00','+05:30') AS marked_at_ist
-- FROM attendance_edit_log e
-- LEFT JOIN UDC_09_USER_ATTENDANCE_STATUS s ON s.id = e.status_id
-- LEFT JOIN user_attributes ua ON ua.ukid = e.modified_by
-- WHERE e.ukid = 392841 AND e.lesson_id = 25416
-- ORDER BY e.updated_time, e.id;
