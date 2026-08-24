-- Student Course Registration Detail Report (component-level), session_id 8
-- One row per student, per registered course, per course component (Lecture/Practical/Tutorial/etc.)
-- for the given course_registration_session -- i.e. a course with 2 components produces 2 rows.
-- Also flags whether the student's class-enrollment (class_student) exists for each component:
--   'Added'             -> class exists for that component and the student is in it
--   'Missing'           -> class exists for that component but the student is NOT in it (the bug)
--   'No Class Created'  -> no class has been created yet for that component this term
--
-- Change arc.session_id (below) and cl.term_id (the course_registration_session's term_id) together
-- to target a different registration session.
--
-- Note: ams_course_registration_student_courses.ams_course_registration_student_id links directly
-- to ams_course_registration_student -- do NOT route through ams_course_registration_student_session,
-- since some rows (admin-added registrations) have a null session link and would be dropped by an
-- inner join through that table.
--
-- Note: some students have duplicate, non-deleted ams_registration_type_clusters rows pointing at
-- the same session_course_id (dirty data), which doubles their registration row for that course.
-- Deduped below via ROW_NUMBER, keeping the most recently created registration per
-- (student, course, component).

SELECT
  `Registration ID`, `Student Name`, `Programme`, `Department`, `Batch`,
  `Course Code`, `Course Name`, `Credits`, `Registration Type`, `Registration Status`,
  `Component`, `Class ID`, `Room`, `Class Enrollment Status`
FROM (
  SELECT
    ua.registration_id AS `Registration ID`,
    CONCAT(ua.f_name, ' ', COALESCE(ua.l_name,'')) AS `Student Name`,
    p.programme_name AS `Programme`,
    d.department_name AS `Department`,
    sp.year_of_joining AS `Batch`,
    co.course_code AS `Course Code`,
    co.course_name AS `Course Name`,
    COALESCE(co.course_credits, arc.course_credits) AS `Credits`,
    acrsc.course_registration_session_type AS `Registration Type`,
    CASE
      WHEN acrsc.is_registered = 1 THEN 'Registered'
      WHEN acrsc.is_waitlisted = 1 THEN 'Waitlisted'
      ELSE 'Not Registered'
    END AS `Registration Status`,
    cct.name AS `Component`,
    cl.id AS `Class ID`,
    cl.room AS `Room`,
    CASE
      WHEN cl.id IS NULL THEN 'No Class Created'
      WHEN cls.id IS NOT NULL THEN 'Added'
      ELSE 'Missing'
    END AS `Class Enrollment Status`,
    ROW_NUMBER() OVER (
      PARTITION BY acrs.ukid, arc.course_id, cc.course_component_type_id
      ORDER BY acrsc.created_timestamp DESC, acrsc.id DESC
    ) AS rn
  FROM ams_registration_session_courses arc
  JOIN ams_registration_type_clusters artc
    ON artc.session_course_id = arc.id AND artc.is_deleted = 0
  JOIN ams_course_registration_student_courses acrsc
    ON acrsc.ams_registration_type_cluster_id = artc.id
  LEFT JOIN ams_course_registration_student acrs
    ON acrs.id = acrsc.ams_course_registration_student_id
  LEFT JOIN course co ON co.course_id = arc.course_id
  LEFT JOIN user_attributes ua ON ua.ukid = acrs.ukid
  LEFT JOIN student_profile sp ON sp.ukid = acrs.ukid
  LEFT JOIN programme p ON p.programme_id = sp.programme_id
  LEFT JOIN department d ON d.department_id = p.department_id
  JOIN course_component cc
    ON cc.course_id = arc.course_id AND cc.course_version_id = arc.course_version_id
  LEFT JOIN course_component_type cct ON cct.id = cc.course_component_type_id
  LEFT JOIN class cl
    ON cl.course_id = arc.course_id
   AND cl.course_component_type_id = cc.course_component_type_id
   AND cl.term_id = 35
  LEFT JOIN class_student cls
    ON cls.class_id = cl.id AND cls.ukid = acrs.ukid
  WHERE arc.session_id = 8
) t
WHERE rn = 1
ORDER BY `Registration ID`, `Course Code`, `Component`;
