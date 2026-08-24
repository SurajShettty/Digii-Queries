SET @sessionId = 8;
SET @termId    = (SELECT term_id FROM course_registration_session WHERE id = @sessionId);

SELECT co.course_code, co.course_name, comp.course_id,
       cct.name AS component, comp.course_component_type_id,
       r.ukid, ua.registration_id,
       CONCAT(ua.f_name,' ',COALESCE(ua.l_name,'')) AS student_name
FROM (
    SELECT DISTINCT c.course_id, c.course_component_type_id
    FROM class c
    WHERE c.term_id = @termId
      AND c.course_id IN (select class.course_id 
from class where class.add_only_course_registered_students = 1 
and class.creation_type = "CUSTOM" and term_id = 65 group by class.course_id)
) comp
JOIN (
    SELECT DISTINCT arc.course_id, acrs.ukid
    FROM ams_registration_session_courses arc
    JOIN ams_registration_type_clusters artc ON artc.session_course_id = arc.id AND artc.is_deleted = 0
    JOIN ams_course_registration_student_courses acrsc
         ON acrsc.ams_registration_type_cluster_id = artc.id
        AND acrsc.is_registered = 1 AND acrsc.is_waitlisted = 0
    JOIN ams_course_registration_student_session acrss ON acrss.id = acrsc.ams_course_registration_student_session_id
    JOIN ams_course_registration_student acrs ON acrs.id = acrss.ams_course_registration_student_id
    WHERE arc.session_id = @sessionId
) r ON r.course_id = comp.course_id
JOIN course co ON co.course_id = comp.course_id
LEFT JOIN course_component_type cct ON cct.id = comp.course_component_type_id
LEFT JOIN user_attributes ua ON ua.ukid = r.ukid
WHERE NOT EXISTS (
    SELECT 1
    FROM class c2
    JOIN class_student cs ON cs.class_id = c2.id
    WHERE c2.course_id = comp.course_id
      AND c2.course_component_type_id = comp.course_component_type_id
      AND c2.term_id = @termId
      AND cs.ukid = r.ukid
)
ORDER BY co.course_code, cct.name, student_name;