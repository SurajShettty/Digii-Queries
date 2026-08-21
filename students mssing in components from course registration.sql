-- Students registered for a multi-component course (session_id 14) who were
-- added to some class components but missed from others.
-- Requires: class rows for the missing component must actually exist
-- (otherwise it's a "class not created" issue, not a "student not added" issue).

SELECT
  d.course_id,
  co.course_code,
  co.course_name,
  d.ukid,
  ua.registration_id,
  CONCAT(ua.f_name, ' ', COALESCE(ua.l_name,'')) AS student_name,
  SUM(d.is_present) AS components_present,
  COUNT(*) AS components_required,
  GROUP_CONCAT(CASE WHEN d.is_present=0 THEN d.component_name END SEPARATOR ', ') AS missing_components,
  GROUP_CONCAT(CASE WHEN d.is_present=1 THEN d.component_name END SEPARATOR ', ') AS added_components
FROM (
  SELECT rs.course_id, rs.ukid,
         rcc.course_component_type_id, cct.name AS component_name,
         MAX(CASE WHEN cls.id IS NOT NULL THEN 1 ELSE 0 END) AS is_present
  FROM (
    -- components that actually have a class created, for this term
    SELECT DISTINCT course_id, course_component_type_id
    FROM class
    WHERE term_id = 41
  ) rcc
  JOIN (
    -- restrict to courses that have MORE THAN ONE component class
    SELECT course_id
    FROM (SELECT DISTINCT course_id, course_component_type_id FROM class WHERE term_id = 41) x
    GROUP BY course_id
    HAVING COUNT(DISTINCT course_component_type_id) > 1
  ) mcc ON mcc.course_id = rcc.course_id
  JOIN (
    -- students who registered (and completed registration) for the course in this session
    SELECT arc.course_id, acrs.ukid
    FROM ams_registration_session_courses arc
    JOIN ams_registration_type_clusters artc
      ON artc.session_course_id = arc.id AND artc.is_deleted = 0
    JOIN ams_course_registration_student_courses acrsc
      ON acrsc.ams_registration_type_cluster_id = artc.id AND acrsc.is_registered = 1
    JOIN ams_course_registration_student_session acrss
      ON acrss.id = acrsc.ams_course_registration_student_session_id
    JOIN ams_course_registration_student acrs
      ON acrs.id = acrss.ams_course_registration_student_id
    WHERE arc.session_id = 14
  ) rs ON rs.course_id = rcc.course_id
  LEFT JOIN course_component_type cct ON cct.id = rcc.course_component_type_id
  LEFT JOIN class cl
    ON cl.course_id = rcc.course_id
   AND cl.course_component_type_id = rcc.course_component_type_id
   AND cl.term_id = 41
  LEFT JOIN class_student cls
    ON cls.class_id = cl.id AND cls.ukid = rs.ukid
  GROUP BY rs.course_id, rs.ukid, rcc.course_component_type_id, cct.name
) d
LEFT JOIN course co ON co.course_id = d.course_id
LEFT JOIN user_attributes ua ON ua.ukid = d.ukid
GROUP BY d.course_id, co.course_code, co.course_name, d.ukid, ua.registration_id, student_name
HAVING SUM(d.is_present) > 0 AND SUM(d.is_present) < COUNT(*)
ORDER BY co.course_code, student_name;
