/*
  Course Registration Timetable - Publish / Unpublish Status Report
  Lists every timetable job along with its current publish status,
  the term it belongs to, the departments it covers, and who created it.
*/
SELECT
    crs.id                                   AS "Session ID",
    crs.session_name                         AS "Session Name",c.course_id,
    c.course_code                            AS "Course Code",
    c.course_name                            AS "Course Name",
    ab.programme_name                        AS "Programme",
    ab.batch_year                            AS "Batch Year",
    s.name                                   AS "Specialisation",
    IF(ct.display_name IS NULL, ct.name, ct.display_name) AS "Enrollment Type",
    -- Cohort status
    CASE
        WHEN ch.cohort_status = 'CONFIGURED' THEN 'Configured'
        ELSE 'Not Configured'
    END                                      AS "Cohort Status",
    -- Slots status (is_slot_faculty_locked ratio over cohort classes)
    CASE
        WHEN ch.id IS NULL OR cls.total_classes IS NULL OR cls.locked_classes = 0
            THEN 'Not Configured'
        WHEN cls.locked_classes = cls.total_classes
            THEN 'Configured'
        ELSE 'Partially Configured'
    END                                      AS "Slots Status",
    -- Timetable status (slot mapping -> timetable_lesson_setting linkage)
    CASE
        WHEN ch.id IS NULL OR cls.total_classes IS NULL
            THEN 'Not Published'
        WHEN crs.is_slot_selection = 0
            THEN 'Not Published'                       -- backend never loads slots otherwise
        WHEN pub.unpublished_classes = 0
            THEN 'Published'
        WHEN pub.published_classes > 0
            THEN 'Partially Published'
        ELSE 'Not Published'
    END                                      AS "Timetable Status"
FROM ams_registration_session_courses arsc
JOIN course_registration_session crs
    ON crs.id = arsc.session_id
JOIN course c
    ON c.course_id = arsc.course_id
JOIN ams_registration_type_clusters atc
    ON atc.session_course_id = arsc.id
JOIN ams_registration_programme_batch ab
    ON ab.registration_type_cluster_id = atc.id
   AND ab.is_deleted = 0
JOIN curriculum_cluster_set cs
    ON cs.id = atc.curriculum_cluster_set_id
JOIN course_registration_type ct
    ON ct.id = cs.course_registration_type_id
   AND ct.is_active = 1
LEFT JOIN programme_specialisation_mapping pm
    ON pm.id = ab.specialisation_mapping_id
LEFT JOIN specialisation s
    ON s.id = pm.specialisation_id
LEFT JOIN ams_cohort_programme_batch_mapping acpbm
    ON acpbm.programme_batch_id = ab.id
LEFT JOIN ams_cohort_configuration ch
    ON ch.id = acpbm.cohort_configuration_id
LEFT JOIN (
    -- cohort classes per configuration: total + slot/faculty locked count
    SELECT
        accbcc.cohort_configuration_id,
        COUNT(*)                                        AS total_classes,
        SUM(accc.is_slot_faculty_locked = 1)            AS locked_classes
    FROM ams_cohort_configuration_by_course_component accbcc
    JOIN ams_cohort_configuration_class accc
        ON accc.cohort_configuration_by_course_id = accbcc.id
    GROUP BY accbcc.cohort_configuration_id
) cls
    ON cls.cohort_configuration_id = ch.id
LEFT JOIN (
    -- per cohort class: unpublished if no slot mappings at all,
    -- or any slot mapping without a timetable_lesson_setting row
    SELECT
        accbcc.cohort_configuration_id,
        SUM(CASE
                WHEN cnt.total_slots IS NULL
                  OR cnt.total_slots = 0
                  OR cnt.published_slots < cnt.total_slots
                THEN 1 ELSE 0
            END)                                        AS unpublished_classes,
        SUM(CASE
                WHEN cnt.published_slots > 0 THEN 1 ELSE 0
            END)                                        AS published_classes
    FROM ams_cohort_configuration_by_course_component accbcc
    JOIN ams_cohort_configuration_class accc
        ON accc.cohort_configuration_by_course_id = accbcc.id
    LEFT JOIN (
        SELECT
            accsm.cohort_configuration_class_id,
            COUNT(*)                                    AS total_slots,
            SUM(tls.id IS NOT NULL)                     AS published_slots
        FROM ams_cohort_class_slot_mapping accsm
        LEFT JOIN timetable_lesson_setting tls
            ON tls.ams_cohort_class_slot_mapping_id = accsm.id
        GROUP BY accsm.cohort_configuration_class_id
    ) cnt
        ON cnt.cohort_configuration_class_id = accc.id
    GROUP BY accbcc.cohort_configuration_id
) pub
    ON pub.cohort_configuration_id = ch.id
WHERE arsc.is_course_active = 1

--  AND crs.id = :sessionId        -- uncomment to filter one session
--  AND arsc.course_id = :courseId -- uncomment to filter one course
ORDER BY
    crs.id,
    c.course_code,
    ab.programme_name,
    ab.batch_year;