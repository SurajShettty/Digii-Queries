-- Student Lifecycle Event report (CHEDS/KHDA format, STUDENT_LIFECYCLE_EVENT sheet).
-- One row per student / graduate with a Record Type:
--   Graduate  = converted to alumni (alumni_profile)
--   Attrition = custom student status set on the profile (Withdrawn / Dropout / Debarred / Transfer / ...)
--   Enrolled  = neither of the above
-- Enrolled-only columns (seq 9-19), leaver-only columns (seq 20-22) and graduate-only columns (seq 23-29) are NULL
-- for the other record types.
-- Academic Period = latest regular term in which the student has courses (course registration or exam enrolment);
-- falls back to the term running on the report date when the student has no courses yet.
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (KHDA Dict)
-- Columns marked "Enhancement Required" / "To Be Checked" have no (reliable) source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    COALESCE(ct.acad_year_start * 100 + ct.sequence * 10,
             (SELECT t.acad_year_start * 100 + t.sequence * 10          -- term running on the report date (programme term preferred over all-programme term)
              FROM term t
              WHERE CURDATE() BETWEEN DATE(t.starts) AND DATE(t.ends)
                AND (t.programme_id = p.programme_id OR (t.all_programmes = 1 AND t.college_id = c.college_id))
              ORDER BY (t.programme_id = p.programme_id) DESC, t.starts DESC
              LIMIT 1))                                                 AS `Academic Period`,
    COALESCE(NULLIF(TRIM(sp.registration_id), ''), ap.registration_id,
             ua.registration_id)                                        AS `Person Id`,
    CASE st.rtype
         WHEN 'G' THEN 'Graduate'
         WHEN 'A' THEN 'Attrition'
         ELSE 'Enrolled'
    END                                                                 AS `Record Type`,                   -- To Be Checked: record type code to be mapped (KHDA Dict)
    p.programme_name                                                    AS `Program Name`,
    COALESCE(ss.major_name, s.name)                                     AS `Program Concentration`,         -- opted major specialisation, else profile specialisation
    tr.first_period                                                     AS `First Academic Period`,         -- first regular term the student had courses in
    c.college_name                                                      AS `Campus`,
    COALESCE(ROUND(cg.cgpa, 2), 0)                                      AS `GPA Cumulative`,                -- latest cumulative CGPA; To Be Checked if scale is not 4 (0 for non-credit programmes)
    CASE WHEN st.rtype = 'E'
         THEN p.system_count END                                        AS `Required Periods Graduation`,   -- regular terms in the programme (e.g. 8 semesters)
    CASE WHEN st.rtype = 'E' THEN
         COALESCE(
             (SELECT das.total_required_credits
              FROM ems_degree_audit_student das
              WHERE das.student_ukid = st.ukid
              ORDER BY das.id DESC
              LIMIT 1),
             (SELECT SUM(COALESCE(cco.course_credits, cv.course_credits)) -- To Be Checked: credits of "COURSE" type courses mapped in the batch curriculum
              FROM curriculum cu
              JOIN curriculum_cluster cc          ON cc.curriculum_id = cu.id
              JOIN curriculum_cluster_set ccs     ON ccs.curriculum_cluster_id = cc.id AND IFNULL(ccs.is_deleted, 0) = 0
              JOIN course_registration_type crt   ON crt.id = ccs.course_registration_type_id AND crt.registration_type = 'COURSE'
              JOIN curriculum_course cco          ON cco.curriculum_cluster_set_id = ccs.id AND IFNULL(cco.is_deleted, 0) = 0
              LEFT JOIN course_version cv         ON cv.id = cco.course_version_id
              WHERE cu.programme_id = sp.programme_id
                AND cu.batch_year = COALESCE(sp.year_of_joining, sp.joining_year)
                AND cu.programme_specialisation_mapping_id IS NULL),
             0)
    END                                                                 AS `Required Credits Graduation`,
    CASE WHEN st.rtype = 'E'
         THEN COALESCE(tr.cur_credits, 0) END                           AS `Currently Registered Credits`,
    CASE WHEN st.rtype = 'E'
         THEN COALESCE(tr.cur_prereq_credits, 0) END                    AS `Prereq Credits Registered`,     -- To Be Checked: current-term courses configured as course registration pre-requisites for the programme
    CASE WHEN st.rtype = 'E'
         THEN COALESCE(tr.total_credits - tr.cur_credits, 0) END        AS `Total Credits Registered Cum`,  -- terms before the current one
    CASE WHEN st.rtype = 'E' THEN
         COALESCE(
             (SELECT SUM(COALESCE(co.course_credits, 0))                -- each course counted once, earned = passed with a grade point (regular or re-exam)
              FROM course co
              WHERE co.course_id IN (SELECT g.course_id
                                     FROM ems_examination_student_course_grade g
                                     JOIN ems_examination ge ON ge.id = g.examination_id
                                     JOIN term gt            ON gt.id = ge.term_id
                                     WHERE g.student_ukid = st.ukid
                                       AND gt.starts < COALESCE(tr.cur_starts, NOW())
                                       AND ((g.is_failed = 0 AND g.grade_point IS NOT NULL)
                                         OR (g.is_failed_for_re_exam = 0 AND g.re_exam_grade_point IS NOT NULL)))), 0)
    END                                                                 AS `Total Credits Completed Cum`,   -- To Be Checked: transferred credits are not captured
    CASE WHEN st.rtype = 'E' AND sp.admission_type = 'TRANSFER'
         THEN cf.previous_institution END                               AS `Transfer Institution`,          -- To Be Checked: previous school/college of transfer admissions
    CASE WHEN st.rtype = 'E' THEN NULL END                              AS `Transfer Credits Cumulative`,   -- Enhancement Required (transfer credits not captured)
    CASE WHEN st.rtype = 'E' THEN 'N' END                               AS `Outgoing Exchange Indicator`,   -- Enhancement Required (exchange not captured)
    CASE WHEN st.rtype = 'E' THEN 'N' END                               AS `Incoming Exchange Indicator`,   -- Enhancement Required (exchange not captured)
    CASE WHEN st.rtype = 'E' AND sp.expected_year_of_passing IS NOT NULL AND p.duration_years > 0 AND p.system_count > 0
         THEN (sp.expected_year_of_passing - 1) * 100
              + ROUND(p.system_count / p.duration_years) * 10
    END                                                                 AS `Expected Graduation Period`,    -- To Be Checked: last term of the final academic year (e.g. 2028 semester programme -> 202720)
    CASE WHEN st.rtype = 'A'
         THEN lt.period_code END                                        AS `Last Active Academic Period`,   -- last exam term the student was enrolled in
    CASE WHEN st.rtype = 'A'
         THEN sst.name END                                              AS `Attrition Category`,            -- custom student status; Leaver Category code to be mapped (KHDA Dict, e.g. VW / TR)
    CASE WHEN st.rtype = 'A'
         THEN COALESCE(NULLIF(TRIM(sp.student_status_remark), ''),
                       cf.leaving_reason,
                       NULLIF(TRIM(sst.description), '')) END           AS `Attrition Reason`,              -- status change remark; Leaver Reason code to be mapped (KHDA Dict)
    CASE WHEN st.rtype = 'G' THEN NULL END                              AS `Thesis Title`,                  -- Enhancement Required ('NT' for non-thesis programmes)
    CASE WHEN st.rtype = 'G' THEN NULL END                              AS `Dissertation Title`,            -- Enhancement Required
    CASE WHEN st.rtype = 'G'
         THEN IF(wp.ukid IS NOT NULL, 'Y', 'N') END                     AS `Workplacement Flag`,            -- To Be Checked: Selected / PLACED in an INTERNSHIP type placement job
    CASE WHEN st.rtype = 'G' AND em.ukid IS NOT NULL
         THEN 'Employed' END                                            AS `Employment Status`,             -- To Be Checked: Selected / PLACED in a FULLTIME placement job; others Enhancement Required
    CASE WHEN st.rtype = 'G'
         THEN NULLIF(em.sector, '') END                                 AS `Employment Sector`,             -- To Be Checked: organisation sector; code to be mapped (Private / Federal Government / ...)
    CASE WHEN st.rtype = 'G'
         THEN NULLIF(em.designation, '') END                            AS `Employment Position`
FROM (
    -- every student and graduate with the record type
    SELECT u.ukid,
           CASE WHEN EXISTS (SELECT 1 FROM alumni_profile ap0 WHERE ap0.ukid = u.ukid)            THEN 'G'
                WHEN EXISTS (SELECT 1 FROM student_profile sp0
                             WHERE sp0.ukid = u.ukid AND sp0.student_status_id IS NOT NULL)      THEN 'A'
                ELSE 'E'
           END AS rtype
    FROM (SELECT ukid FROM student_profile
          UNION
          SELECT ukid FROM alumni_profile) u
) st
JOIN user_attributes ua          ON ua.ukid = st.ukid
LEFT JOIN student_profile sp     ON sp.ukid = st.ukid
LEFT JOIN alumni_profile ap      ON ap.ukid = st.ukid
LEFT JOIN student_status sst     ON sst.id = sp.student_status_id
LEFT JOIN college c              ON c.college_id = COALESCE(sp.college_id, ua.college_id)
LEFT JOIN programme p            ON p.programme_id = COALESCE(ap.programme_id, sp.programme_id)
LEFT JOIN specialisation s       ON s.id = COALESCE(ap.specialisation_id, sp.specialisation_id)
LEFT JOIN (
    -- student profile custom fields; list fields store the list item id
    SELECT v.ukid,
           MAX(CASE WHEN f.identifier = 'PREVIOUS_SCHOOL_COLLEGE_NAME' THEN NULLIF(TRIM(v.value), '') END)  AS previous_institution,
           MAX(CASE WHEN f.identifier = 'STUDENT_REASON_FOR_LEAVING_UNIVERSITY_STATUS_LIST' THEN li.name END) AS leaving_reason
    FROM user_details_master_field_value v
    JOIN student_profile sp2                        ON sp2.ukid = v.ukid
    JOIN user_details_master_field f                ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id AND li.id = v.value
    WHERE f.identifier IN ('PREVIOUS_SCHOOL_COLLEGE_NAME', 'STUDENT_REASON_FOR_LEAVING_UNIVERSITY_STATUS_LIST')
    GROUP BY v.ukid
) cf ON cf.ukid = st.ukid
LEFT JOIN (
    -- major specialisations opted by the student
    SELECT pss.ukid,
           GROUP_CONCAT(DISTINCT sx.name ORDER BY sx.name SEPARATOR ', ') AS major_name
    FROM programme_specialisation_student pss
    JOIN programme_specialisation_mapping psm ON psm.id = pss.programme_specialisation_mapping_id AND IFNULL(psm.is_deleted, 0) = 0
                                             AND psm.specialisation_type = 'MAJOR'
    JOIN specialisation sx                    ON sx.id = psm.specialisation_id
    GROUP BY pss.ukid
) ss ON ss.ukid = st.ukid
LEFT JOIN (
    -- per student: first / current term and credits. Current term = latest regular term (supplementary terms only when
    -- the student has no regular term); its credits are picked from the per-term rows via the MAX(CONCAT(sort key, value)) trick.
    -- Key = <1 regular / 0 supplementary><starts yyyymmddhhmmss><term id 10> -> 25 chars.
    SELECT stc.ukid,
           CAST(SUBSTRING(MIN(CONCAT(stc.supplementary, DATE_FORMAT(stc.starts, '%Y%m%d'), stc.period_code)), 10) AS UNSIGNED)   AS first_period,
           CAST(SUBSTRING(MAX(CONCAT(1 - stc.supplementary, DATE_FORMAT(stc.starts, '%Y%m%d%H%i%s'),
                                     LPAD(stc.term_id, 10, '0'))), 16) AS UNSIGNED)                                               AS cur_term_id,
           CAST(SUBSTRING(MAX(CONCAT(1 - stc.supplementary, DATE_FORMAT(stc.starts, '%Y%m%d%H%i%s'),
                                     LPAD(stc.term_id, 10, '0'), stc.credits)), 26) AS DECIMAL(10, 2))                            AS cur_credits,
           CAST(SUBSTRING(MAX(CONCAT(1 - stc.supplementary, DATE_FORMAT(stc.starts, '%Y%m%d%H%i%s'),
                                     LPAD(stc.term_id, 10, '0'), stc.prereq_credits)), 26) AS DECIMAL(10, 2))                     AS cur_prereq_credits,
           STR_TO_DATE(SUBSTRING(MAX(CONCAT(1 - stc.supplementary, DATE_FORMAT(stc.starts, '%Y%m%d%H%i%s'))), 2), '%Y%m%d%H%i%s') AS cur_starts,
           SUM(stc.credits)                                                                                                       AS total_credits
    FROM (
        -- credits per student per term
        SELECT sc.ukid, t.id AS term_id, t.starts,
               IFNULL(t.additional_term, 0)                                          AS supplementary,
               t.acad_year_start * 100 + t.sequence * 10                             AS period_code,
               SUM(COALESCE(tc.course_credits, co.course_credits, 0))                AS credits,
               SUM(CASE WHEN pr.course_id IS NOT NULL
                        THEN COALESCE(tc.course_credits, co.course_credits, 0) ELSE 0 END) AS prereq_credits
        FROM (
            -- courses the student has: course registration or exam enrolment
            SELECT r.ukid, r.term_course_id
            FROM ems_student_course_registration_details r
            UNION
            SELECT spe.ukid, sce.term_course_id
            FROM ems_student_programme_enrollment spe
            JOIN ems_student_course_enrollment sce ON sce.student_programme_enrollment_id = spe.id
                                                  AND sce.enrollment_status IN ('ENROLLED', 'AUTO_ENROLLED')
        ) sc
        JOIN term_course tc               ON tc.id = sc.term_course_id
        JOIN term t                       ON t.id = tc.term_id
        LEFT JOIN course co               ON co.course_id = tc.course_id
        LEFT JOIN student_profile sp5     ON sp5.ukid = sc.ukid
        LEFT JOIN (
            -- courses configured as course registration pre-requisites per programme
            SELECT DISTINCT rpb.programme_id, pr.course_id
            FROM ams_registration_programme_batch_pre_requisites pr
            JOIN ams_registration_programme_batch rpb ON rpb.id = pr.registration_programme_batch_id
                                                     AND IFNULL(rpb.is_deleted, 0) = 0
        ) pr ON pr.programme_id = sp5.programme_id AND pr.course_id = tc.course_id
        GROUP BY sc.ukid, t.id, t.starts, t.additional_term, t.acad_year_start, t.sequence
    ) stc
    GROUP BY stc.ukid
) tr ON tr.ukid = st.ukid
LEFT JOIN term ct                ON ct.id = tr.cur_term_id
LEFT JOIN (
    -- last exam term in which the student was enrolled in courses (exam programme enrolment with enrolled courses)
    SELECT et.ukid,
           CAST(SUBSTRING(MAX(CONCAT(DATE_FORMAT(et.starts, '%Y%m%d'), et.period_code)), 9) AS UNSIGNED) AS period_code
    FROM (
        SELECT DISTINCT spe.ukid, t.starts,
               t.acad_year_start * 100 + t.sequence * 10 AS period_code
        FROM ems_student_programme_enrollment spe
        JOIN student_profile sp3 ON sp3.ukid = spe.ukid AND sp3.student_status_id IS NOT NULL
        JOIN ems_examination ee  ON ee.id = spe.exam_id
        JOIN term t              ON t.id = ee.term_id
        WHERE EXISTS (SELECT 1
                      FROM ems_student_course_enrollment sce
                      WHERE sce.student_programme_enrollment_id = spe.id
                        AND sce.enrollment_status IN ('ENROLLED', 'AUTO_ENROLLED'))
    ) et
    GROUP BY et.ukid
) lt ON lt.ukid = st.ukid
LEFT JOIN (
    -- latest cumulative CGPA (latest term, then latest generated row)
    SELECT g.student_ukid,
           CAST(SUBSTRING(MAX(CONCAT(DATE_FORMAT(t.starts, '%Y%m%d'), LPAD(g.id, 12, '0'),
                                     COALESCE(g.degree_moderated_cgpa, g.re_exam_cgpa, g.cgpa))), 21) AS DECIMAL(10, 4)) AS cgpa
    FROM ems_examination_student_cgpa g
    JOIN ems_examination e  ON e.id = g.exam_id
    JOIN term t             ON t.id = e.term_id
    WHERE COALESCE(g.degree_moderated_cgpa, g.re_exam_cgpa, g.cgpa) IS NOT NULL
    GROUP BY g.student_ukid
) cg ON cg.student_ukid = st.ukid
LEFT JOIN (
    -- students Selected / PLACED in an internship
    SELECT DISTINCT pa.ukid
    FROM placement_application pa
    JOIN placement_job j                  ON j.id = pa.job_id AND IFNULL(j.is_deleted, 0) = 0
    JOIN placement_types ptp              ON ptp.id = j.placement_type_id AND ptp.type = 'INTERNSHIP'
    JOIN placement_application_status ast ON ast.id = pa.status_id AND ast.name IN ('Selected', 'PLACED')
) wp ON wp.ukid = st.ukid
LEFT JOIN (
    -- latest full-time placement (latest application) per student; sector = parent sector, else sector
    SELECT pa.ukid,
           SUBSTRING(MAX(CONCAT(LPAD(pa.id, 12, '0'), COALESCE(ps.name, s.name, ''))), 13)       AS sector,
           SUBSTRING(MAX(CONCAT(LPAD(pa.id, 12, '0'), COALESCE(TRIM(j.designation), ''))), 13)  AS designation
    FROM placement_application pa
    JOIN placement_job j                       ON j.id = pa.job_id AND IFNULL(j.is_deleted, 0) = 0
    JOIN placement_types ptp                   ON ptp.id = j.placement_type_id AND ptp.type = 'FULLTIME'
    JOIN placement_application_status ast      ON ast.id = pa.status_id AND ast.name IN ('Selected', 'PLACED')
    LEFT JOIN placement_organization po        ON po.id = j.organization_id
    LEFT JOIN placement_organization_sector s  ON s.id = po.sector_id
    LEFT JOIN placement_organization_sector ps ON ps.id = s.parent_id
    GROUP BY pa.ukid
) em ON em.ukid = st.ukid
ORDER BY `Record Type`, `Academic Period` DESC, `Person Id`;
