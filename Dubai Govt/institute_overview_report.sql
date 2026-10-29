-- Institute Overview report (CHEDS/KHDA INSTITUTE - OVERVIEW sheet).
-- One row per institution (college), columns in the order of the spec (seq 1 - 52).
-- Sources: college (Institutional Settings), student_profile / user_attributes / authenticator (headcounts),
--   term + exam enrolment (drop-out rate), Infrastructure Management (infrastructure_master -> infrastructure_version /
--   infrastructure_type, hostel_allotment, asset_allotment), Transport Management (transport_allotment),
--   institution_entity + department (divisions), lesson (contact minutes).
-- Infrastructure counts follow the spec's short-term solution: non archived infrastructure of the college, matched by
--   type name (Classroom, Laboratory, Library, Research Centre, Activity, Career, Sport / Gym / Swimming pool, Parking).
--   Types that are not set up yet (Research Centre, Career, Activity, Parking) report N / 0 until they are created.
-- Academic Year = academic year of the college's current term: latest regular (non-additional) term that has started
--   (all-programme term of the college, else a term of one of the college's programmes); falls back to the academic year
--   starting in September when the college has no term. Coded <start year><end year YY>, e.g. 2026-27 -> 202627.
-- Columns marked "Enhancement Required" have no source field yet (digii status "New DB Table Required") and are NULL.
-- Columns marked "To Be Checked" are derived values that need to be confirmed against the CHEDS definition / code list.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,              -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    COALESCE(
        (SELECT t.acad_year_start * 100 + MOD(t.acad_year_start + 1, 100) -- academic year of the current term of the college
         FROM term t
         WHERE ((t.all_programmes = 1 AND t.college_id = c.college_id)
                OR t.programme_id IN (SELECT pr.programme_id FROM programme pr WHERE pr.college_id = c.college_id))
           AND IFNULL(t.additional_term, 0) = 0
           AND t.starts <= CURDATE()
         ORDER BY t.starts DESC, t.id DESC
         LIMIT 1),
        (YEAR(CURDATE()) - (MONTH(CURDATE()) < 9)) * 100                -- no term set up: academic year starting in September
          + MOD(YEAR(CURDATE()) - (MONTH(CURDATE()) < 9) + 1, 100))     AS `Academic Year`,
    c.financial_status                                                  AS `Institution Type`,              -- To Be Checked: Institutional Settings financial status (PRIVATE / ...), map to the CHEDS Institution Type list (e.g. PR)
    CASE WHEN c.institution_type = 'CO_EDUCATION'                       THEN 'CE'
         WHEN c.institution_type IN ('MALE', 'BOYS', 'MEN')             THEN 'M'
         WHEN c.institution_type IN ('FEMALE', 'GIRLS', 'WOMEN')        THEN 'F'
         WHEN st.female_students > 0 AND st.male_students > 0           THEN 'CE'
         WHEN st.female_students > 0                                    THEN 'F'
         WHEN st.male_students > 0                                      THEN 'M' END AS `Institution Gender`, -- Institutional Settings institution type, falls back to active students' gender; NCE is not captured
    NULL                                                                AS `Institutional Accreditation Body`, -- Enhancement Required (semicolon separated Accreditation Body codes)
    NULL                                                                AS `Date international accreditation`, -- Enhancement Required (DD/MM/YYYY; ..., same order as the accreditation bodies)
    NULL                                                                AS `International accreditation expiration`, -- Enhancement Required (DD/MM/YYYY; ..., same order as the accreditation bodies)
    NULL                                                                AS `Faculty Resignations`,          -- Enhancement Required (separation reason in the staff offboarding workflow)
    NULL                                                                AS `Staff Resignations`,            -- Enhancement Required (separation reason in the staff offboarding workflow)
    NULL                                                                AS `Facilities Ownership`,          -- Enhancement Required (Ownership Type on the Building: O / R / U)
    NULL                                                                AS `Total area of Facilities`,      -- Enhancement Required (built area in sq. m on infrastructure)
    NULL                                                                AS `Total area of Classrooms`,      -- Enhancement Required
    NULL                                                                AS `Total area of Labs`,            -- Enhancement Required
    NULL                                                                AS `Total area of Libraries`,       -- Enhancement Required
    NULL                                                                AS `Total area of Residential area`, -- Enhancement Required
    NULL                                                                AS `Total area for Student Services`, -- Enhancement Required
    NULL                                                                AS `Total area for Administration`, -- Enhancement Required
    CONCAT(IF(ho.female_occupants > 0, 'Y', 'N'), 'F',
           IF(ho.male_occupants > 0, 'Y', 'N'), 'M')                    AS `Accommodations`,                -- To Be Checked: Y/N female + Y/N male confirmed hostel occupants (e.g. NFNM), map to the Accommodation facilities list
    IF(inf.activity_centres > 0, 'Y', 'N')                              AS `Student activities Centre`,     -- infra type like '%activit%'
    IF(inf.career_centres > 0, 'Y', 'N')                                AS `Careers Centre`,                -- infra type like '%career%'
    IF(inf.sports_facilities > 0, 'Y', 'N')                             AS `Sports Facilities`,             -- infra type Sports and Recreation / Gym / Swimming pool
    COALESCE(NULLIF(inf.parking_capacity, 0), inf.parking_areas, 0)     AS `Parking Spaces`,                -- capacity of parking infra, falls back to the number of parking infra
    NULL                                                                AS `Availability of facilities / services for People of Determination (Special Needs)`, -- Enhancement Required (Y / N)
    NULL                                                                AS `Types of facilities / services for People of Determination (Special needs)`,        -- Enhancement Required (special needs category codes, ';' separated)
    CONCAT(IF(tp.female_users > 0, 'Y', 'N'), 'F',
           IF(tp.male_users > 0, 'Y', 'N'), 'M')                        AS `Transportation`,                -- To Be Checked: Y/N female + Y/N male confirmed transport allotments (e.g. YFYM), map to the Transportation Type list
    NULL                                                                AS `Language of Instruction`,       -- Enhancement Required (Institutional Settings)
    COALESCE(inf.classrooms, 0)                                         AS `Classrooms`,                    -- infra type = 'Classroom'
    COALESCE(inf.laboratories, 0)                                       AS `Laboratories`,                  -- infra type = 'Laboratory' / 'Lab'
    ROUND(st.active_students / NULLIF(fc.active_faculty, 0), 2)         AS `Student - faculty ratio`,       -- To Be Checked: active students / active faculty headcount (CHEDS may use FTE)
    ROUND(100 * dr.leavers / NULLIF(dr.enrolled, 0), 2)                 AS `Student-Drop out Rate`,         -- To Be Checked: % of students enrolled in the previous term who have since left (custom student status, not alumni)
    inf.research_centres                                                AS `List of Research Centres`,      -- infra type like 'Research Cent%', comma separated
    dv.divisions                                                        AS `Names of top-level divisions/Names of administrative departments or units`, -- To Be Checked: Faculty-layer entities + non academic departments, ';' separated
    NULL                                                                AS `Library: Databases`,            -- Enhancement Required (Library Management)
    NULL                                                                AS `Library: Inter-Library Loan Indicator`, -- Enhancement Required (Y / N)
    NULL                                                                AS `Library: Books`,                -- Enhancement Required (Library holdings)
    COALESCE(lc.computers, 0)                                           AS `Library: Computers`,            -- To Be Checked: computer / laptop / desktop assets currently allotted to Library infrastructure
    inf.library_hours_per_week                                          AS `Library: Hours`,                -- To Be Checked: longest daily opening hours of Library infrastructure x 7 days (opening days are not captured)
    NULL                                                                AS `Library: Journals`,             -- Enhancement Required (Item Type = Journal)
    NULL                                                                AS `Library: Textbooks`,            -- Enhancement Required (Item Type = Textbook)
    NULL                                                                AS `Library: E-books`,              -- Enhancement Required (Item Type = E-Book)
    NULL                                                                AS `Library: E-media`,              -- Enhancement Required (Item Type = E-Media)
    NULL                                                                AS `Library E-serial`,              -- Enhancement Required (Item Type = E-Serials)
    cm.contact_minutes                                                  AS `Contact Minutes`,               -- To Be Checked: most common lesson (class) duration in minutes over the last 12 months
    NULL                                                                AS `Environmental Accommodations`,  -- Enhancement Required (Y / N)
    NULL                                                                AS `Details of Environmental Accommodations`, -- Enhancement Required
    NULL                                                                AS `Assessment Accommodations`,     -- Enhancement Required (Y / N)
    NULL                                                                AS `Assessment Accommodations details`, -- Enhancement Required
    NULL                                                                AS `Instructional Accommodations`,  -- Enhancement Required (Y / N)
    NULL                                                                AS `Instructional Accommodations details`, -- Enhancement Required
    NULL                                                                AS `International Branch Campus Accreditation`, -- Enhancement Required (Y / N, international branch campuses only)
    DATE_FORMAT(CURDATE(), '%Y-%m-%d')                                  AS `Last Updated`                   -- report date
FROM college c
LEFT JOIN (
    -- active students (no custom student status, not alumni, active login) by gender
    SELECT COALESCE(sp.college_id, ua.college_id)       AS college_id,
           COUNT(*)                                     AS active_students,
           SUM(LOWER(sp.gender) = 'female')             AS female_students,
           SUM(LOWER(sp.gender) = 'male')               AS male_students
    FROM student_profile sp
    JOIN user_attributes ua ON ua.ukid = sp.ukid
    JOIN authenticator a    ON a.ukid = sp.ukid AND a.is_active = 1
    WHERE sp.student_status_id IS NULL
      AND NOT EXISTS (SELECT 1 FROM alumni_profile ap WHERE ap.ukid = sp.ukid)
    GROUP BY COALESCE(sp.college_id, ua.college_id)
) st ON st.college_id = c.college_id
LEFT JOIN (
    -- active faculty headcount
    SELECT ua.college_id, COUNT(*) AS active_faculty
    FROM user_attributes ua
    JOIN authenticator a ON a.ukid = ua.ukid AND a.is_active = 1
    WHERE ua.user_type = 'faculty'
    GROUP BY ua.college_id
) fc ON fc.college_id = c.college_id
LEFT JOIN (
    -- students enrolled in courses in the previous regular term and how many of them have left since
    SELECT x.college_id, COUNT(*) AS enrolled, SUM(x.has_left) AS leavers
    FROM (
        SELECT DISTINCT
               COALESCE(sp.college_id, ua.college_id)   AS college_id,
               spe.ukid,
               (sp.student_status_id IS NOT NULL
                AND NOT EXISTS (SELECT 1 FROM alumni_profile ap WHERE ap.ukid = sp.ukid)) AS has_left
        FROM ems_student_programme_enrollment spe
        JOIN ems_examination ee  ON ee.id = spe.exam_id
        JOIN term t              ON t.id = ee.term_id AND IFNULL(t.additional_term, 0) = 0
        JOIN (
            -- latest regular term that has ended and has exam enrolments
            SELECT MAX(t2.acad_year_start * 100 + t2.sequence * 10) AS period_code
            FROM term t2
            WHERE DATE(t2.ends) < CURDATE() AND IFNULL(t2.additional_term, 0) = 0
              AND EXISTS (SELECT 1
                          FROM ems_examination ee2
                          JOIN ems_student_programme_enrollment spe2 ON spe2.exam_id = ee2.id
                          WHERE ee2.term_id = t2.id)
        ) prev ON prev.period_code = t.acad_year_start * 100 + t.sequence * 10
        JOIN student_profile sp  ON sp.ukid = spe.ukid
        JOIN user_attributes ua  ON ua.ukid = spe.ukid
        WHERE EXISTS (SELECT 1
                      FROM ems_student_course_enrollment sce
                      WHERE sce.student_programme_enrollment_id = spe.id
                        AND sce.enrollment_status IN ('ENROLLED', 'AUTO_ENROLLED'))
    ) x
    GROUP BY x.college_id
) dr ON dr.college_id = c.college_id
LEFT JOIN (
    -- non archived infrastructure of the college by type name
    SELECT
        iv.college_id,
        SUM(LOWER(it.type) = 'classroom')                                              AS classrooms,
        SUM(LOWER(it.type) IN ('laboratory', 'lab'))                                    AS laboratories,
        SUM(LOWER(it.type) LIKE '%activit%')                                            AS activity_centres,
        SUM(LOWER(it.type) LIKE '%career%')                                             AS career_centres,
        SUM(LOWER(it.type) LIKE '%sport%' OR LOWER(it.type) LIKE '%gym%'
            OR LOWER(it.type) LIKE '%swimming%')                                        AS sports_facilities,
        SUM(LOWER(it.type) LIKE '%parking%')                                            AS parking_areas,
        SUM(CASE WHEN LOWER(it.type) LIKE '%parking%' THEN iv.capacity END)             AS parking_capacity,
        GROUP_CONCAT(DISTINCT CASE WHEN LOWER(it.type) LIKE 'research cent%' THEN iv.name END
                     ORDER BY iv.name SEPARATOR ', ')                                   AS research_centres,
        ROUND(7 * MAX(CASE WHEN LOWER(it.type) = 'library'
                           THEN TIME_TO_SEC(TIMEDIFF(iv.closing_time, iv.opening_time)) / 3600 END)) AS library_hours_per_week
    FROM infrastructure_master im
    JOIN infrastructure_version iv ON iv.id = im.infrastructure_version_id
    JOIN infrastructure_type it    ON it.id = im.type_id
    WHERE im.archived = 0
    GROUP BY iv.college_id
) inf ON inf.college_id = c.college_id
LEFT JOIN (
    -- computer assets currently allotted to library infrastructure
    SELECT iv.college_id, COUNT(DISTINCT aa.asset_id) AS computers
    FROM asset_allotment aa
    JOIN infrastructure_version iv ON iv.id = aa.infrastructure_id
    JOIN infrastructure_type it    ON it.id = iv.type_id AND LOWER(it.type) = 'library'
    JOIN asset a                   ON a.id = aa.asset_id AND a.is_deleted = 0
    JOIN asset_product ap          ON ap.id = a.product_id
    JOIN asset_category ac         ON ac.id = ap.category_id
    WHERE aa.status = 'confirmed' AND aa.alloted_status = 'ALLOTED'
      AND (LOWER(ac.name) LIKE '%comput%' OR LOWER(ac.name) LIKE '%laptop%' OR LOWER(ac.name) LIKE '%desktop%'
           OR LOWER(ap.name) LIKE '%comput%' OR LOWER(ap.name) LIKE '%laptop%' OR LOWER(ap.name) LIKE '%desktop%')
    GROUP BY iv.college_id
) lc ON lc.college_id = c.college_id
CROSS JOIN (
    -- current (confirmed) hostel occupants by gender
    SELECT SUM(LOWER(sp.gender) = 'female') AS female_occupants,
           SUM(LOWER(sp.gender) = 'male')   AS male_occupants
    FROM hostel_allotment ha
    JOIN student_profile sp ON sp.ukid = ha.occupant_ukid
    WHERE ha.status = 'confirmed'
) ho
CROSS JOIN (
    -- confirmed transport allotments of active users by gender
    SELECT SUM(LOWER(COALESCE(sp.gender, fp.gender, ap.gender)) = 'female') AS female_users,
           SUM(LOWER(COALESCE(sp.gender, fp.gender, ap.gender)) = 'male')   AS male_users
    FROM transport_allotment ta
    JOIN authenticator a         ON a.ukid = ta.ukid AND a.is_active = 1
    LEFT JOIN student_profile sp ON sp.ukid = ta.ukid
    LEFT JOIN faculty_profile fp ON fp.ukid = ta.ukid
    LEFT JOIN admin_profile ap   ON ap.ukid = ta.ukid
    WHERE ta.status = 'CONFIRMED'
) tp
CROSS JOIN (
    -- top-level academic divisions (Faculty layer) followed by the administrative (non academic) departments
    SELECT GROUP_CONCAT(u.name ORDER BY u.grp, u.name SEPARATOR '; ') AS divisions
    FROM (
        SELECT 1 AS grp, TRIM(ie.name) AS name
        FROM institution_entity ie
        JOIN institution_layer il ON il.id = ie.layer_id AND il.name = 'Faculty'
        UNION
        SELECT 2, TRIM(d.department_name)
        FROM department d
        WHERE d.category = 'non academic'
    ) u
) dv
CROSS JOIN (
    -- most common lesson duration over the last 12 months
    SELECT MAX(d.mins) AS contact_minutes
    FROM (
        SELECT TIMESTAMPDIFF(MINUTE, l.start, l.end) AS mins
        FROM lesson l
        WHERE l.start >= CURDATE() - INTERVAL 12 MONTH
          AND l.end > l.start
        GROUP BY TIMESTAMPDIFF(MINUTE, l.start, l.end)
        ORDER BY COUNT(*) DESC
        LIMIT 1
    ) d
) cm
ORDER BY `Institution Name`;
