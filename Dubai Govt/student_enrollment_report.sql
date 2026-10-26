-- Students - Enrollment report (CHEDS/KHDA format).
-- One row per currently enrolled student = student profile with no custom student status (not Withdrawn / Dropout / etc.)
-- who has not been converted to alumni (leavers and graduates are reported in the Attrition / Graduates reports).
-- Academic Period = latest regular term in which the student has courses (course registration or exam enrolment);
-- falls back to the term running on the report date when the student has no courses yet.
-- "Till last academic period" figures only count terms that started before that Academic Period.
-- Personal / prior-education details come from student_profile, falling back to the student profile custom fields
-- (user_details_master_field_value).
-- Academic periods are coded as <acad_year_start><term sequence>0, e.g. 2025-26 term 1 -> 202510. To be mapped (KHDA Dict)
-- Columns marked "Enhancement Required" / "To Be Checked" have no (reliable) source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,              -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    COALESCE(ct.acad_year_start * 100 + ct.sequence * 10,
             (SELECT t.acad_year_start * 100 + t.sequence * 10          -- term running on the report date (programme term preferred over all-programme term)
              FROM term t
              WHERE CURDATE() BETWEEN DATE(t.starts) AND DATE(t.ends)
                AND (t.programme_id = p.programme_id OR (t.all_programmes = 1 AND t.college_id = c.college_id))
              ORDER BY (t.programme_id = p.programme_id) DESC, t.starts DESC
              LIMIT 1))                                                 AS `Academic Period`,
    COALESCE(NULLIF(TRIM(sp.registration_id), ''), ua.registration_id)  AS `Student ID`,
    NULL                                                                AS `Al Khulasa`,                    -- Enhancement Required (UAE nationals only, else 'NA')
    '999999999999999'                                                   AS `Emirates ID`,                   -- Enhancement Required (999999999999999 when not available)
    COALESCE(NULLIF(TRIM(sp.passport_number), ''), cf.passport_number,
             'NA')                                                      AS `Passport Number`,
    NULL                                                                AS `Reason for Missing EID`,        -- Enhancement Required
    NULL                                                                AS `Family Book Number`,            -- Enhancement Required (UAE nationals only)
    NULL                                                                AS `Family Number`,                 -- Enhancement Required (UAE nationals only)
    NULL                                                                AS `City Number`,                   -- Enhancement Required (UAE nationals only)
    TRIM(CONCAT_WS(' ', NULLIF(TRIM(ua.f_name), ''),
                        NULLIF(TRIM(ua.m_name), ''),
                        NULLIF(TRIM(ua.l_name), '')))                   AS `Student Name (English)`,
    NULL                                                                AS `Student Name (Arabic)`,         -- Enhancement Required (blank when not available)
    CASE LOWER(sp.gender)
         WHEN 'male'   THEN 'M'
         WHEN 'female' THEN 'F'
         ELSE 'U'
    END                                                                 AS `Gender`,
    DATE_FORMAT(sp.date_of_birth, '%Y-%m-%d')                           AS `Student DOB`,
    COALESCE(NULLIF(TRIM(a.email), ''),
             NULLIF(TRIM(ua.secondary_email), ''),
             'xxx@xxx.com')                                             AS `Student Email Address`,
    COALESCE(NULLIF(TRIM(a.phone), ''),
             NULLIF(TRIM(sp.phone), ''),
             NULLIF(TRIM(ua.secondary_phone), ''),
             '+999-99-9999999')                                         AS `Student Mobile Number`,
    CASE cf.physically_disabled
         WHEN 'Yes' THEN 'Y'
         WHEN 'No'  THEN 'N'
         ELSE 'U'
    END                                                                 AS `People of Determination (Special Needs Indicator)`, -- To Be Checked (only "physically disabled" is captured)
    NULL                                                                AS `People of Determination Category`, -- Enhancement Required (mandatory when indicator = 'Y')
    COALESCE(NULLIF(TRIM(sp.marital_status), ''), cf.marital_status)    AS `Marital Status`,                -- Marital status code to be mapped (KHDA Dict)
    COALESCE(NULLIF(TRIM(sp.nationality), ''), cf.nationality,
             NULLIF(TRIM(sp.citizenship), ''))                          AS `Nationality`,                   -- Nationality code to be mapped (KHDA Dict)
    NULL                                                                AS `Nationality of Mother`,         -- Enhancement Required
    NULL                                                                AS `Home Emirate (Emirates Code)`,  -- Enhancement Required
    NULL                                                                AS `Student Campus (Campus Code)`,  -- Enhancement Required (campus code not captured)
    CASE
         WHEN sp.admission_type = 'TRANSFER'                     THEN 'TR'
         WHEN tr.first_period IS NULL
           OR tr.first_period = ct.acad_year_start * 100 + ct.sequence * 10 THEN 'NW'
         ELSE 'CN'
    END                                                                 AS `Student Type (Type Code)`,      -- To Be Checked: transfer / new (first period) / continuing; Student Type code to be mapped (KHDA Dict)
    tr.first_period                                                     AS `1st Academic Period`,           -- first regular term the student had courses in
    CASE
         WHEN pt.name = 'Undergraduate' THEN
              CASE WHEN sp.year <= 1 THEN 'FR'
                   WHEN sp.year = 2  THEN 'SO'
                   WHEN sp.year = 3  THEN 'JR'
                   WHEN sp.year >= 4 THEN 'SR'
              END
         ELSE pt.name
    END                                                                 AS `Student Level (Level Code)`,    -- To Be Checked: UG from current year of study; others to be mapped (KHDA Dict)
    pt.name                                                             AS `Student Degree (Degree Code)`,  -- Degree code to be mapped (KHDA Dict, e.g. BA)
    NULL                                                                AS `Area of Specialization (CIP Family code)`, -- Enhancement Required ('99' for unclassified programmes)
    COALESCE(ss.major_name, s.name, p.programme_name)                   AS `Student Major (text)`,
    NULL                                                                AS `Student Major (CIP Major Classification)`, -- Enhancement Required ('99.9999' for unclassified programmes)
    ss.minor_name                                                       AS `Student Minor`,
    p.programme_code                                                    AS `Student Program (Program Code)`, -- Program code to be mapped (KHDA Dict)
    CASE
         WHEN cf.mode_of_study IN ('Full-Time', 'Regular') THEN 'FT'
         WHEN cf.mode_of_study = 'Part-Time'               THEN 'PT'
    END                                                                 AS `Mode of Study (FT/PT)`,         -- To Be Checked (Online/Distance/Correspondence not mapped)
    cf.employment_status                                                AS `Employment Status`,             -- To Be Checked: employment status code to be mapped (KHDA Dict)
    cf.employment_sector                                                AS `Employment Sector`,             -- To Be Checked: employment type stands in for sector (KHDA Dict)
    cf.designation                                                      AS `Employment Position`,
    p.system_count                                                      AS `Required academic periods for Graduation`, -- regular terms in the programme (e.g. 8 semesters)
    COALESCE(
        (SELECT das.total_required_credits
         FROM ems_degree_audit_student das
         WHERE das.student_ukid = sp.ukid
         ORDER BY das.id DESC
         LIMIT 1),
        (SELECT SUM(COALESCE(cco.course_credits, cv.course_credits))    -- To Be Checked: credits of "COURSE" type courses mapped in the batch curriculum
         FROM curriculum cu
         JOIN curriculum_cluster cc          ON cc.curriculum_id = cu.id
         JOIN curriculum_cluster_set ccs     ON ccs.curriculum_cluster_id = cc.id AND IFNULL(ccs.is_deleted, 0) = 0
         JOIN course_registration_type crt   ON crt.id = ccs.course_registration_type_id AND crt.registration_type = 'COURSE'
         JOIN curriculum_course cco          ON cco.curriculum_cluster_set_id = ccs.id AND IFNULL(cco.is_deleted, 0) = 0
         LEFT JOIN course_version cv         ON cv.id = cco.course_version_id
         WHERE cu.programme_id = sp.programme_id
           AND cu.batch_year = COALESCE(sp.year_of_joining, sp.joining_year)
           AND cu.programme_specialisation_mapping_id IS NULL))         AS `Required Credits for Graduation`,
    COALESCE(tr.cur_credits, 0)                                         AS `Currently Registered Credits`,
    COALESCE(tr.cur_prereq_credits, 0)                                  AS `Currently Registered Pre-requisite Credits`, -- To Be Checked: current-term courses configured as course registration pre-requisites for the programme
    COALESCE(tr.total_credits - tr.cur_credits, 0)                      AS `Total Credits Registered (cumulative - till last Academic period)`,
    COALESCE(
        (SELECT SUM(COALESCE(co.course_credits, 0))                     -- each course counted once, earned = passed with a grade point (regular or re-exam)
         FROM course co
         WHERE co.course_id IN (SELECT g.course_id
                                FROM ems_examination_student_course_grade g
                                JOIN ems_examination ge ON ge.id = g.examination_id
                                JOIN term gt            ON gt.id = ge.term_id
                                WHERE g.student_ukid = sp.ukid
                                  AND gt.starts < COALESCE(tr.cur_starts, NOW())
                                  AND ((g.is_failed = 0 AND g.grade_point IS NOT NULL)
                                    OR (g.is_failed_for_re_exam = 0 AND g.re_exam_grade_point IS NOT NULL)))), 0) AS `Total Credits Completed (cumulative - till last academic period)`,
    ROUND(
        (SELECT CAST(SUBSTRING(MAX(CONCAT(DATE_FORMAT(t.starts, '%Y%m%d'), LPAD(g.id, 12, '0'),
                                          COALESCE(g.degree_moderated_cgpa, g.re_exam_cgpa, g.cgpa))), 21) AS DECIMAL(10, 4))
         FROM ems_examination_student_cgpa g
         JOIN ems_examination e ON e.id = g.exam_id
         JOIN term t            ON t.id = e.term_id
         WHERE g.student_ukid = sp.ukid
           AND t.starts < COALESCE(tr.cur_starts, NOW())
           AND COALESCE(g.degree_moderated_cgpa, g.re_exam_cgpa, g.cgpa) IS NOT NULL), 2) AS `Overall GPA (cumulative - till last Academic period)`, -- latest CGPA before the Academic Period; To Be Checked if scale is not 4 (0 for non-credit programmes)
    CASE WHEN sp.admission_type = 'TRANSFER'
         THEN cf.previous_institution END                               AS `Transfer Institution`,          -- To Be Checked: previous school/college of transfer admissions
    NULL                                                                AS `Transfer Credits Cumulative`,   -- Enhancement Required (transfer credits not captured)
    CASE WHEN cf.ielts_score IS NOT NULL THEN 'IELTS'
         WHEN cf.toefl_score IS NOT NULL THEN 'TOEFL'
    END                                                                 AS `Language Test Proficiency Exam`, -- English test code to be mapped (KHDA Dict)
    CASE WHEN cf.ielts_score IS NOT NULL THEN cf.ielts_year
         WHEN cf.toefl_score IS NOT NULL THEN cf.toefl_year
    END                                                                 AS `Language Test Proficiency Exam Pass Date`, -- To Be Checked: only the year of passing is captured
    COALESCE(cf.ielts_score, cf.toefl_score)                            AS `Language Test Proficiency Exam Score`,
    CASE WHEN cf.gmat_score IS NOT NULL THEN 'GMAT'
         WHEN cf.gre_score  IS NOT NULL THEN 'GRE'
    END                                                                 AS `Standardized Test Name (for Masters and Above)`, -- Standardized test code to be mapped (KHDA Dict)
    COALESCE(cf.gmat_score, cf.gre_score)                               AS `Standardized Test Score (for Masters and Above)`,
    NULL                                                                AS `High School - Country Code`,    -- Enhancement Required
    cf.hsc_board                                                        AS `High School System`,            -- To Be Checked: board name; High School System code to be mapped (KHDA Dict)
    COALESCE(cf.hsc_percentage, NULLIF(TRIM(sp.hsc_marks), ''))          AS `High School Exit Score`,
    cf.hsc_year                                                         AS `High School Completion Year`,   -- To Be Checked: CHEDS expects the academic year code
    NULL                                                                AS `High School Equivalency Indicator`, -- Enhancement Required (Y/R/A/N/U)
    NULL                                                                AS `High School Equivalency Number`,    -- Enhancement Required
    cf.hsc_stream                                                       AS `12th Grade stream (Stream Code)`,   -- Stream code to be mapped (KHDA Dict; 'NA' for non-MOE curriculum)
    COALESCE(cf.ug_degree, cf.highest_qualification)                    AS `Last Completed Higher Education Degree`, -- Degree code to be mapped (KHDA Dict)
    cf.previous_institution                                             AS `Last Completed Higher Education Institution Name`, -- To Be Checked
    NULL                                                                AS `Last Completed Higher Education Institution Country`, -- Enhancement Required
    NULL                                                                AS `Last Completed Higher Education Institution CODE`,    -- Enhancement Required
    cf.ug_cgpa                                                          AS `Last Completed Higher Education Degree CGPA`,         -- To Be Checked: map to the 4-point scale
    cf.ug_year                                                          AS `Last Completed Higher Education Year`,                -- To Be Checked: CHEDS expects the academic year code
    NULL                                                                AS `Last Completed Higher Education Equivalency Indicator`, -- Enhancement Required
    NULL                                                                AS `Last Completed Higher Education Equivalency Number`,    -- Enhancement Required
    'N'                                                                 AS `Outgoing Exchange student Indicator`, -- Enhancement Required (exchange not captured)
    'N'                                                                 AS `Incoming Exchange Student Indicator`, -- Enhancement Required (exchange not captured)
    NULL                                                                AS `Exchange partner university code`,    -- Enhancement Required
    'N'                                                                 AS `Enrolled in joint/dual program`,      -- Enhancement Required
    CASE WHEN sp.expected_year_of_passing IS NOT NULL AND p.duration_years > 0 AND p.system_count > 0
         THEN (sp.expected_year_of_passing - 1) * 100
              + ROUND(p.system_count / p.duration_years) * 10
    END                                                                 AS `Expected Graduation period`,    -- To Be Checked: last term of the final academic year (e.g. 2028 semester programme -> 202720)
    DATE_FORMAT(GREATEST(COALESCE(sp.modified_timestamp, sp.updated_timestamp, sp.last_modified, ua.updated_timestamp),
                         COALESCE(ua.updated_timestamp, sp.modified_timestamp, sp.updated_timestamp, sp.last_modified)),
                '%Y-%m-%d')                                             AS `Last Updated`
FROM student_profile sp
JOIN user_attributes ua          ON ua.ukid = sp.ukid
LEFT JOIN authenticator a        ON a.ukid = sp.ukid
LEFT JOIN college c              ON c.college_id = COALESCE(sp.college_id, ua.college_id)
LEFT JOIN programme p            ON p.programme_id = sp.programme_id
LEFT JOIN programme_types pt     ON pt.id = p.programme_type_id
LEFT JOIN specialisation s       ON s.id = sp.specialisation_id
LEFT JOIN (
    -- student profile custom fields; list fields store the list item id
    SELECT v.ukid,
           MAX(CASE WHEN f.identifier = 'NATIONALITY'                  THEN NULLIF(TRIM(v.value), '') END) AS nationality,
           MAX(CASE WHEN f.identifier = 'PASSPORT_NUMBER'              THEN NULLIF(TRIM(v.value), '') END) AS passport_number,
           MAX(CASE WHEN f.identifier = 'MARITAL_STATUS'               THEN li.name END)                  AS marital_status,
           MAX(CASE WHEN f.identifier = 'IS_PHYSICALLY_DISABLED'       THEN li.name END)                  AS physically_disabled,
           MAX(CASE WHEN f.identifier = 'GRADUATION_MODE_OF_STUDY'     THEN li.name END)                  AS mode_of_study,
           MAX(CASE WHEN f.identifier = 'EMPLOYMENT_STATUS'            THEN NULLIF(TRIM(v.value), '') END) AS employment_status,
           MAX(CASE WHEN f.identifier = 'EMPLOYMENT_TYPE'              THEN li.name END)                  AS employment_sector,
           MAX(CASE WHEN f.identifier = 'DESIGNATION'                  THEN NULLIF(TRIM(v.value), '') END) AS designation,
           MAX(CASE WHEN f.identifier = 'IELTS_COMPOSITE_SCORE'        THEN NULLIF(TRIM(v.value), '') END) AS ielts_score,
           MAX(CASE WHEN f.identifier = 'IELTS_YEAR_OF_PASSING'        THEN NULLIF(TRIM(v.value), '') END) AS ielts_year,
           MAX(CASE WHEN f.identifier = 'TOEFL_COMPOSITE_SCORE'        THEN NULLIF(TRIM(v.value), '') END) AS toefl_score,
           MAX(CASE WHEN f.identifier = 'TOEFL_YEAR_OF_PASSING'        THEN NULLIF(TRIM(v.value), '') END) AS toefl_year,
           MAX(CASE WHEN f.identifier = 'GMAT_COMPOSITE_SCORE'         THEN NULLIF(TRIM(v.value), '') END) AS gmat_score,
           MAX(CASE WHEN f.identifier = 'GRE_COMPOSITE_SCORE'          THEN NULLIF(TRIM(v.value), '') END) AS gre_score,
           MAX(CASE WHEN f.identifier = 'HSC_NAME_OF_BOARD'            THEN NULLIF(TRIM(v.value), '') END) AS hsc_board,
           MAX(CASE WHEN f.identifier = 'HSC_PERCENTAGE'               THEN NULLIF(TRIM(v.value), '') END) AS hsc_percentage,
           MAX(CASE WHEN f.identifier = 'HSC_YEAR_OF_PASSING'          THEN NULLIF(TRIM(v.value), '') END) AS hsc_year,
           MAX(CASE WHEN f.identifier = 'HSC_STREAM'                   THEN NULLIF(TRIM(v.value), '') END) AS hsc_stream,
           MAX(CASE WHEN f.identifier = 'GRADUATION1_TYPE_OF_DEGREE'   THEN NULLIF(TRIM(v.value), '') END) AS ug_degree,
           MAX(CASE WHEN f.identifier = 'HIGHEST_QUALIFICATION'        THEN NULLIF(TRIM(v.value), '') END) AS highest_qualification,
           MAX(CASE WHEN f.identifier = 'PREVIOUS_SCHOOL_COLLEGE_NAME' THEN NULLIF(TRIM(v.value), '') END) AS previous_institution,
           MAX(CASE WHEN f.identifier = 'UG_OBTAINED_CGPA'             THEN NULLIF(TRIM(v.value), '') END) AS ug_cgpa,
           MAX(CASE WHEN f.identifier = 'UG_YEAR_OF_PASSING'           THEN NULLIF(TRIM(v.value), '') END) AS ug_year
    FROM user_details_master_field_value v
    JOIN student_profile sp2                        ON sp2.ukid = v.ukid AND sp2.student_status_id IS NULL
    JOIN user_details_master_field f                ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id AND li.id = v.value
    WHERE f.identifier IN ('NATIONALITY', 'PASSPORT_NUMBER', 'MARITAL_STATUS', 'IS_PHYSICALLY_DISABLED',
                           'GRADUATION_MODE_OF_STUDY', 'EMPLOYMENT_STATUS', 'EMPLOYMENT_TYPE', 'DESIGNATION',
                           'IELTS_COMPOSITE_SCORE', 'IELTS_YEAR_OF_PASSING', 'TOEFL_COMPOSITE_SCORE', 'TOEFL_YEAR_OF_PASSING',
                           'GMAT_COMPOSITE_SCORE', 'GRE_COMPOSITE_SCORE',
                           'HSC_NAME_OF_BOARD', 'HSC_PERCENTAGE', 'HSC_YEAR_OF_PASSING', 'HSC_STREAM',
                           'GRADUATION1_TYPE_OF_DEGREE', 'HIGHEST_QUALIFICATION', 'PREVIOUS_SCHOOL_COLLEGE_NAME',
                           'UG_OBTAINED_CGPA', 'UG_YEAR_OF_PASSING')
    GROUP BY v.ukid
) cf ON cf.ukid = sp.ukid
LEFT JOIN (
    -- major / minor specialisations opted by the student
    SELECT pss.ukid,
           GROUP_CONCAT(DISTINCT CASE WHEN psm.specialisation_type = 'MAJOR' THEN sx.name END ORDER BY sx.name SEPARATOR ', ') AS major_name,
           GROUP_CONCAT(DISTINCT CASE WHEN psm.specialisation_type = 'MINOR' THEN sx.name END ORDER BY sx.name SEPARATOR ', ') AS minor_name
    FROM programme_specialisation_student pss
    JOIN programme_specialisation_mapping psm ON psm.id = pss.programme_specialisation_mapping_id AND IFNULL(psm.is_deleted, 0) = 0
    JOIN specialisation sx                    ON sx.id = psm.specialisation_id
    GROUP BY pss.ukid
) ss ON ss.ukid = sp.ukid
LEFT JOIN (
    -- per student: first / current term and credits. Current term = latest regular term (supplementary terms only when
    -- the student has no regular term); its credits are picked from the per-term rows via the MAX(CONCAT(sort key, value)) trick.
    -- Key = <1 regular / 0 supplementary><starts yyyymmddhhmmss><term id 10> -> 25 chars.
    SELECT st.ukid,
           CAST(SUBSTRING(MIN(CONCAT(st.supplementary, DATE_FORMAT(st.starts, '%Y%m%d'), st.period_code)), 10) AS UNSIGNED)   AS first_period,
           CAST(SUBSTRING(MAX(CONCAT(1 - st.supplementary, DATE_FORMAT(st.starts, '%Y%m%d%H%i%s'),
                                     LPAD(st.term_id, 10, '0'))), 16) AS UNSIGNED)                                              AS cur_term_id,
           CAST(SUBSTRING(MAX(CONCAT(1 - st.supplementary, DATE_FORMAT(st.starts, '%Y%m%d%H%i%s'),
                                     LPAD(st.term_id, 10, '0'), st.credits)), 26) AS DECIMAL(10, 2))                            AS cur_credits,
           CAST(SUBSTRING(MAX(CONCAT(1 - st.supplementary, DATE_FORMAT(st.starts, '%Y%m%d%H%i%s'),
                                     LPAD(st.term_id, 10, '0'), st.prereq_credits)), 26) AS DECIMAL(10, 2))                     AS cur_prereq_credits,
           STR_TO_DATE(SUBSTRING(MAX(CONCAT(1 - st.supplementary, DATE_FORMAT(st.starts, '%Y%m%d%H%i%s'))), 2), '%Y%m%d%H%i%s') AS cur_starts,
           SUM(st.credits)                                                                                                      AS total_credits
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
    ) st
    GROUP BY st.ukid
) tr ON tr.ukid = sp.ukid
LEFT JOIN term ct                ON ct.id = tr.cur_term_id
WHERE sp.student_status_id IS NULL                                            -- leavers are reported in the Attrition report
  AND NOT EXISTS (SELECT 1 FROM alumni_profile ap WHERE ap.ukid = sp.ukid)    -- graduates are reported in the Graduates report
ORDER BY `Academic Period` DESC, `Student ID`;
