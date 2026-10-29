-- Education Background report (CHEDS/KHDA EDUCATION_BACKGROUND sheet).
-- One row per active student, faculty or administrator (employee) user (active login in authenticator), same population
--   and Person Id / Person Type Flag as the Person Profile report.
-- Student columns (High School / Last Higher Education / tests) are filled for students only; Employee columns for faculty /
--   administrators only.
-- Sources: Student Management / ePortfolio custom fields (user_details_master_field_value, list fields resolved to the item
--   name) + the employee's most recently completed ePortfolio QUALIFICATION_DETAILS entry (highest qualification).
-- Fields marked "Custom Field" in the spec do not exist yet; they are read from the custom field identifiers named in the
--   column comments (HIGH_SCHOOL_COUNTRY, ...) and fall back to the existing fields (HSC_*, UG_*, IELTS_*, ...) where one exists.
-- Equivalency indicators are reduced to their code letter (Yes -> Y, Mutual -> M, Rejected -> R, Applied -> A,
--   Not Required / No -> N, Unknown -> U, Transferred -> T); other values are reported as NULL.
-- Columns marked "To Be Checked" need the value mapped to the spec's code list.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    COALESCE(NULLIF(TRIM(sp.registration_id), ''),
             NULLIF(TRIM(ua.registration_id), ''), ua.ukid)             AS `Person Id`,
    CASE ua.user_type
         WHEN 'student' THEN 'Student'
         WHEN 'faculty' THEN 'Faculty'
         ELSE 'Employee' END                                            AS `Person Type Flag`,
    -- ---------- students ----------
    CASE WHEN ua.user_type = 'student' THEN cf.hs_country END           AS `High School Country`,           -- Custom field HIGH_SCHOOL_COUNTRY; To Be Checked: map to ISO 3166 Alpha-2 / Alpha-3 code
    CASE WHEN ua.user_type = 'student'
         THEN COALESCE(cf.hs_curriculum, cf.hsc_board) END              AS `High School Curriculum System`, -- Custom field HIGH_SCHOOL_CURRICULUM_SYSTEM, falls back to HSC_NAME_OF_BOARD; To Be Checked: map to KHDA code
    CASE WHEN ua.user_type = 'student'
         THEN REPLACE(COALESCE(cf.hs_exit_score, cf.hsc_percentage,
                               NULLIF(TRIM(sp.hsc_marks), '')), '%', '') END AS `High School Exit Score`,   -- Custom field HIGH_SCHOOL_EXIT_SCORE, falls back to HSC_PERCENTAGE / profile HSC marks
    CASE WHEN ua.user_type = 'student'
         THEN COALESCE(cf.hs_year, cf.hsc_year) END                     AS `High School Completion Year`,   -- Custom field HIGH_SCHOOL_COMPLETION_YEAR, falls back to HSC_YEAR_OF_PASSING; To Be Checked: academic year code
    CASE WHEN ua.user_type = 'student'
          AND LEFT(cf.hs_equivalency, 1) IN ('Y', 'M', 'R', 'A', 'N', 'U')
         THEN LEFT(cf.hs_equivalency, 1) END                            AS `High School Equivalency Indicator`, -- Custom field HIGH_SCHOOL_EQUIVALENCY_INDICATOR (Y / M / R / A / N / U)
    CASE WHEN ua.user_type = 'student'
         THEN COALESCE(cf.grade12_stream, cf.hsc_stream) END            AS `Grade 12 Stream`,               -- Custom field GRADE_12_STREAM, falls back to HSC_STREAM; To Be Checked: map to KHDA stream code
    CASE WHEN ua.user_type = 'student'
         THEN COALESCE(cf.lhe_degree, cf.ug_degree,
                       cf.highest_qualification) END                    AS `Last Higher Education Degree`,  -- Custom field LAST_HIGHER_EDUCATION_DEGREE, falls back to GRADUATION1_TYPE_OF_DEGREE / HIGHEST_QUALIFICATION; To Be Checked: degree code
    CASE WHEN ua.user_type = 'student'
         THEN COALESCE(cf.lhe_institution,
                       CASE WHEN COALESCE(cf.lhe_degree, cf.ug_degree) IS NOT NULL
                            THEN cf.previous_institution END) END       AS `Last Higher Education Institution Name`, -- Custom field LAST_HIGHER_EDUCATION_INSTITUTION_NAME, falls back to PREVIOUS_SCHOOL_COLLEGE_NAME when a degree is entered
    CASE WHEN ua.user_type = 'student' THEN cf.lhe_country END          AS `Last Higher Education Institution Country`, -- Custom field LAST_HIGHER_EDUCATION_INSTITUTION_COUNTRY; To Be Checked: map to ISO 3166 code
    CASE WHEN ua.user_type = 'student'
         THEN COALESCE(cf.lhe_cgpa, cf.ug_cgpa) END                     AS `Last Higher Education Degree CGPA`, -- Custom field LAST_HIGHER_EDUCATION_DEGREE_CGPA, falls back to UG_OBTAINED_CGPA; To Be Checked: 4.0 scale
    CASE WHEN ua.user_type = 'student'
         THEN COALESCE(cf.lhe_year, cf.ug_year) END                     AS `Last Higher Education Completion Year`, -- Custom field LAST_HIGHER_EDUCATION_COMPLETION_YEAR, falls back to UG_YEAR_OF_PASSING; To Be Checked: academic year code
    CASE WHEN ua.user_type = 'student'
          AND LEFT(cf.lhe_equivalency, 1) IN ('Y', 'R', 'A', 'N', 'U', 'T')
         THEN LEFT(cf.lhe_equivalency, 1) END                           AS `Last Higher Education Equivalency Indicator`, -- Custom field LAST_HIGHER_EDUCATION_EQUIVALENCY_INDICATOR (Y / R / A / N / U / T)
    CASE WHEN ua.user_type = 'student'
         THEN COALESCE(cf.language_test,
                       CASE WHEN cf.ielts_score IS NOT NULL THEN 'IELTS'
                            WHEN cf.toefl_score IS NOT NULL THEN 'TOEFL' END) END AS `Language Proficiency Test`, -- Custom field LANGUAGE_PROFICIENCY_TEST, falls back to the IELTS / TOEFL score entered; To Be Checked: KHDA code
    CASE WHEN ua.user_type = 'student'
         THEN COALESCE(cf.standardised_test,
                       CASE WHEN cf.gmat_score IS NOT NULL THEN 'GMAT'
                            WHEN cf.gre_score  IS NOT NULL THEN 'GRE' END) END AS `Standardised Test Name Postgraduate`, -- Custom field STANDARDISED_TEST_NAME_POSTGRADUATE, falls back to the GMAT / GRE score entered
    -- ---------- employees (faculty / administrators) ----------
    CASE WHEN ua.user_type <> 'student'
         THEN COALESCE(q.qualification, cf.highest_qualification) END   AS `Employee Qualification`,        -- QUALIFICATION_DETAILS > QUALIFICATION, falls back to HIGHEST_QUALIFICATION; To Be Checked: degree code (e.g. DR)
    CASE WHEN ua.user_type <> 'student'
         THEN COALESCE(q.country, cf.emp_qual_country) END              AS `Employee Qualification Country`, -- Custom field QUALIFICATION_COUNTRY (qualification entry) / EMPLOYEE_QUALIFICATION_COUNTRY; To Be Checked: ISO 3166 code
    CASE WHEN ua.user_type <> 'student'
         THEN COALESCE(q.institute_name, q.university_name) END         AS `Employee Qualification Institution Name`,
    CASE WHEN ua.user_type <> 'student'
         THEN LEFT(q.completed_on, 4) END                               AS `Employee Qualification Year`,   -- year of COMPLETED_ON
    CASE WHEN ua.user_type <> 'student' THEN q.degree END               AS `Employee Qualification Name`,
    CASE WHEN ua.user_type <> 'student' THEN q.specialization END       AS `Employee Qualification Major`,
    CASE WHEN ua.user_type <> 'student'
          AND LEFT(COALESCE(q.equivalency, cf.emp_equivalency), 1) IN ('Y', 'R', 'A', 'N', 'U', 'T')
         THEN LEFT(COALESCE(q.equivalency, cf.emp_equivalency), 1) END  AS `Employee Equivalency Indicator`, -- Custom field EQUIVALENCY_INDICATOR (qualification entry) / EMPLOYEE_EQUIVALENCY_INDICATOR
    CASE WHEN ua.user_type <> 'student'
         THEN COALESCE(q.equivalency_number, cf.emp_equivalency_number) END AS `Employee Equivalency Number` -- Custom field EQUIVALENCY_NUMBER (qualification entry) / EMPLOYEE_EQUIVALENCY_NUMBER
FROM user_attributes ua
JOIN authenticator a              ON a.ukid = ua.ukid AND a.is_active = 1
LEFT JOIN student_profile sp      ON sp.ukid = ua.ukid AND ua.user_type = 'student'
LEFT JOIN (
    -- person custom fields; list fields store the list item id
    SELECT
        v.ukid,
        MAX(CASE WHEN f.identifier = 'HIGH_SCHOOL_COUNTRY'                         THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS hs_country,
        MAX(CASE WHEN f.identifier = 'HIGH_SCHOOL_CURRICULUM_SYSTEM'               THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS hs_curriculum,
        MAX(CASE WHEN f.identifier = 'HIGH_SCHOOL_EXIT_SCORE'                      THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS hs_exit_score,
        MAX(CASE WHEN f.identifier = 'HIGH_SCHOOL_COMPLETION_YEAR'                 THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS hs_year,
        MAX(CASE WHEN f.identifier = 'HIGH_SCHOOL_EQUIVALENCY_INDICATOR'           THEN UPPER(NULLIF(TRIM(COALESCE(li.name, v.value)), '')) END) AS hs_equivalency,
        MAX(CASE WHEN f.identifier = 'GRADE_12_STREAM'                             THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS grade12_stream,
        MAX(CASE WHEN f.identifier = 'LAST_HIGHER_EDUCATION_DEGREE'                THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS lhe_degree,
        MAX(CASE WHEN f.identifier = 'LAST_HIGHER_EDUCATION_INSTITUTION_NAME'      THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS lhe_institution,
        MAX(CASE WHEN f.identifier = 'LAST_HIGHER_EDUCATION_INSTITUTION_COUNTRY'   THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS lhe_country,
        MAX(CASE WHEN f.identifier = 'LAST_HIGHER_EDUCATION_DEGREE_CGPA'           THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS lhe_cgpa,
        MAX(CASE WHEN f.identifier = 'LAST_HIGHER_EDUCATION_COMPLETION_YEAR'       THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS lhe_year,
        MAX(CASE WHEN f.identifier = 'LAST_HIGHER_EDUCATION_EQUIVALENCY_INDICATOR' THEN UPPER(NULLIF(TRIM(COALESCE(li.name, v.value)), '')) END) AS lhe_equivalency,
        MAX(CASE WHEN f.identifier = 'LANGUAGE_PROFICIENCY_TEST'                   THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS language_test,
        MAX(CASE WHEN f.identifier = 'STANDARDISED_TEST_NAME_POSTGRADUATE'         THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS standardised_test,
        MAX(CASE WHEN f.identifier = 'EMPLOYEE_QUALIFICATION_COUNTRY'              THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS emp_qual_country,
        MAX(CASE WHEN f.identifier = 'EMPLOYEE_EQUIVALENCY_INDICATOR'              THEN UPPER(NULLIF(TRIM(COALESCE(li.name, v.value)), '')) END) AS emp_equivalency,
        MAX(CASE WHEN f.identifier = 'EMPLOYEE_EQUIVALENCY_NUMBER'                 THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS emp_equivalency_number,
        -- existing fields used as fallbacks
        MAX(CASE WHEN f.identifier = 'HSC_NAME_OF_BOARD'                           THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS hsc_board,
        MAX(CASE WHEN f.identifier = 'HSC_PERCENTAGE'                              THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS hsc_percentage,
        MAX(CASE WHEN f.identifier = 'HSC_YEAR_OF_PASSING'                         THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS hsc_year,
        MAX(CASE WHEN f.identifier = 'HSC_STREAM'                                  THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS hsc_stream,
        MAX(CASE WHEN f.identifier = 'GRADUATION1_TYPE_OF_DEGREE'                  THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS ug_degree,
        MAX(CASE WHEN f.identifier = 'HIGHEST_QUALIFICATION'                       THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS highest_qualification,
        MAX(CASE WHEN f.identifier = 'PREVIOUS_SCHOOL_COLLEGE_NAME'                THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS previous_institution,
        MAX(CASE WHEN f.identifier = 'UG_OBTAINED_CGPA'                            THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS ug_cgpa,
        MAX(CASE WHEN f.identifier = 'UG_YEAR_OF_PASSING'                          THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS ug_year,
        MAX(CASE WHEN f.identifier = 'IELTS_COMPOSITE_SCORE'                       THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS ielts_score,
        MAX(CASE WHEN f.identifier = 'TOEFL_COMPOSITE_SCORE'                       THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS toefl_score,
        MAX(CASE WHEN f.identifier = 'GMAT_COMPOSITE_SCORE'                        THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS gmat_score,
        MAX(CASE WHEN f.identifier = 'GRE_COMPOSITE_SCORE'                         THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS gre_score
    FROM user_details_master_field_value v
    JOIN user_details_master_field f                ON f.id = v.field_id
    LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id AND li.id = v.value
    WHERE f.identifier IN ('HIGH_SCHOOL_COUNTRY', 'HIGH_SCHOOL_CURRICULUM_SYSTEM', 'HIGH_SCHOOL_EXIT_SCORE',
                           'HIGH_SCHOOL_COMPLETION_YEAR', 'HIGH_SCHOOL_EQUIVALENCY_INDICATOR', 'GRADE_12_STREAM',
                           'LAST_HIGHER_EDUCATION_DEGREE', 'LAST_HIGHER_EDUCATION_INSTITUTION_NAME',
                           'LAST_HIGHER_EDUCATION_INSTITUTION_COUNTRY', 'LAST_HIGHER_EDUCATION_DEGREE_CGPA',
                           'LAST_HIGHER_EDUCATION_COMPLETION_YEAR', 'LAST_HIGHER_EDUCATION_EQUIVALENCY_INDICATOR',
                           'LANGUAGE_PROFICIENCY_TEST', 'STANDARDISED_TEST_NAME_POSTGRADUATE',
                           'EMPLOYEE_QUALIFICATION_COUNTRY', 'EMPLOYEE_EQUIVALENCY_INDICATOR', 'EMPLOYEE_EQUIVALENCY_NUMBER',
                           'HSC_NAME_OF_BOARD', 'HSC_PERCENTAGE', 'HSC_YEAR_OF_PASSING', 'HSC_STREAM',
                           'GRADUATION1_TYPE_OF_DEGREE', 'HIGHEST_QUALIFICATION', 'PREVIOUS_SCHOOL_COLLEGE_NAME',
                           'UG_OBTAINED_CGPA', 'UG_YEAR_OF_PASSING', 'IELTS_COMPOSITE_SCORE', 'TOEFL_COMPOSITE_SCORE',
                           'GMAT_COMPOSITE_SCORE', 'GRE_COMPOSITE_SCORE')
    GROUP BY v.ukid
) cf ON cf.ukid = ua.ukid
LEFT JOIN (
    -- QUALIFICATION_DETAILS entries pivoted, then the latest completed entry per user (same as Employee Basic Details)
    SELECT qe.*
    FROM (
        SELECT
            v.ukid,
            v.cluster_entry_id,
            MAX(CASE WHEN f.identifier = 'QUALIFICATION'            THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS qualification,
            MAX(CASE WHEN f.identifier = 'DEGREE'                   THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS degree,
            MAX(CASE WHEN f.identifier = 'AREA_OF_SPECIALIZATION'   THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS specialization,
            MAX(CASE WHEN f.identifier = 'INSTITUTE_NAME'           THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS institute_name,
            MAX(CASE WHEN f.identifier = 'UNIVERSITY_OR_BOARD_NAME' THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS university_name,
            MAX(CASE WHEN f.identifier = 'COMPLETED_ON'             THEN NULLIF(TRIM(v.value), '') END)                    AS completed_on,
            MAX(CASE WHEN f.identifier = 'QUALIFICATION_COUNTRY'    THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS country,
            MAX(CASE WHEN f.identifier = 'EQUIVALENCY_INDICATOR'    THEN UPPER(NULLIF(TRIM(COALESCE(li.name, v.value)), '')) END) AS equivalency,
            MAX(CASE WHEN f.identifier = 'EQUIVALENCY_NUMBER'       THEN NULLIF(TRIM(COALESCE(li.name, v.value)), '') END) AS equivalency_number
        FROM user_details_master_cluster_entry_field_value v
        JOIN user_details_master_field f                ON f.id = v.field_id
        LEFT JOIN user_details_master_field_list_item li ON f.element = 'list' AND li.field_id = f.id AND li.id = v.value
        WHERE f.identifier IN ('QUALIFICATION', 'DEGREE', 'AREA_OF_SPECIALIZATION', 'INSTITUTE_NAME',
                               'UNIVERSITY_OR_BOARD_NAME', 'COMPLETED_ON', 'QUALIFICATION_COUNTRY',
                               'EQUIVALENCY_INDICATOR', 'EQUIVALENCY_NUMBER')
          AND NULLIF(TRIM(v.value), '') IS NOT NULL
        GROUP BY v.ukid, v.cluster_entry_id
    ) qe
    JOIN (
        SELECT v.ukid,
               SUBSTRING_INDEX(GROUP_CONCAT(v.cluster_entry_id
                                            ORDER BY IF(f.identifier = 'COMPLETED_ON', v.value, '') DESC,
                                                     v.cluster_entry_id DESC), ',', 1) AS cluster_entry_id
        FROM user_details_master_cluster_entry_field_value v
        JOIN user_details_master_field f ON f.id = v.field_id
        WHERE f.identifier IN ('QUALIFICATION', 'DEGREE', 'COMPLETED_ON')
          AND NULLIF(TRIM(v.value), '') IS NOT NULL
        GROUP BY v.ukid
    ) latest ON latest.ukid = qe.ukid AND latest.cluster_entry_id = qe.cluster_entry_id
) q ON q.ukid = ua.ukid AND ua.user_type <> 'student'
WHERE ua.user_type IN ('student', 'faculty', 'administrator')
ORDER BY `Person Type Flag`, `Person Id`;
