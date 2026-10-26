-- CLOs report (CHEDS/KHDA format).
-- One row per course learning outcome (obe_course_outcomes, defined per term course) + programme.
-- A course offered to several programmes is listed once per programme. Programme comes from the course's classes in that
-- term (programme batch sections, else students added to the class, else class programme), else from curriculum mapping.
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (CHEDS Semester Code list)
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT DISTINCT
    c.university_code                                                   AS `Institution Code`,          -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    p.programme_code                                                    AS `Program Code`,              -- Program code to be mapped (KHDA Dict)
    p.programme_name                                                    AS `Program Name`,
    t.acad_year_start * 100 + t.sequence * 10                           AS `Academic Period`,
    COALESCE(NULLIF(TRIM(tc.course_name), ''), NULLIF(TRIM(tcv.course_name), ''),
             NULLIF(TRIM(dcv.course_name), ''), co.course_name)         AS `Course Name`,   -- term snapshot, else term / default course version
    COALESCE(NULLIF(TRIM(tc.course_code), ''), NULLIF(TRIM(tcv.course_code), ''),
             NULLIF(TRIM(dcv.course_code), ''), co.course_code)         AS `Course code`,
    CONCAT(COALESCE(NULLIF(TRIM(tc.course_code), ''), NULLIF(TRIM(tcv.course_code), ''),
                    NULLIF(TRIM(dcv.course_code), ''), co.course_code),
           '-', TRIM(o.code))                                           AS `CLO code`,                  -- <course code>-<CO code>, e.g. CS101-CO1
    TRIM(o.description)                                                 AS `CLO Description`,
    DATE_FORMAT(o.modified_timestamp, '%Y-%m-%d')                       AS `Last Updated`
FROM obe_course_outcomes o
JOIN term_course tc                          ON tc.id = o.term_course_id
JOIN term t                                  ON t.id = tc.term_id
LEFT JOIN course co                          ON co.course_id = tc.course_id
LEFT JOIN course_version tcv                 ON tcv.id = tc.course_version_id
LEFT JOIN course_version dcv                 ON dcv.course_id = tc.course_id AND dcv.is_default = 1
LEFT JOIN (
    -- programmes of a term course: from its classes in that term
    SELECT cl.term_id, cl.course_id, COALESCE(cps.programme_id, cl.programme_id) AS programme_id
    FROM class cl
    LEFT JOIN (
        SELECT class_id, programme_id
        FROM class_programme_batch_sections
        WHERE programme_id IS NOT NULL
        UNION
        SELECT cs.class_id, sp.programme_id
        FROM class_student cs
        JOIN student_profile sp ON sp.ukid = cs.ukid
        WHERE sp.programme_id IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM class_programme_batch_sections b
                          WHERE b.class_id = cs.class_id AND b.programme_id IS NOT NULL)
    ) cps ON cps.class_id = cl.id
    WHERE COALESCE(cps.programme_id, cl.programme_id) IS NOT NULL
) clp ON clp.term_id = tc.term_id AND clp.course_id = tc.course_id
LEFT JOIN (
    -- fallback: programmes whose curriculum maps the course
    SELECT DISTINCT ccc.course_id, cu.programme_id
    FROM curriculum_course ccc
    JOIN curriculum_cluster_set ccs ON ccs.id = ccc.curriculum_cluster_set_id
    JOIN curriculum_cluster cc      ON cc.id  = ccs.curriculum_cluster_id
    JOIN curriculum cu              ON cu.id  = cc.curriculum_id
    WHERE ccc.is_deleted = 0
      AND cu.programme_id IS NOT NULL
) cup ON cup.course_id = tc.course_id AND clp.programme_id IS NULL
LEFT JOIN programme p                        ON p.programme_id = COALESCE(clp.programme_id, cup.programme_id, t.programme_id)
LEFT JOIN college c                          ON c.college_id = COALESCE(p.college_id, t.college_id)
WHERE o.is_deleted = 0
ORDER BY `Academic Period` DESC, `Program Code`, `Course code`, `CLO code`;
