-- Applicants - Basic Details report (CHEDS/KHDA format).
-- One row per institution + admission academic period + degree + programme (programme stands in for the CIP area of specialisation).
-- Grain of an application = student_admission_form_status (one row per applicant per admission category = programme + batch + quota).
--   Number of Applicants          = all applications that reached the admissions team for a decision
--   Number of Admissions Offered  = applications in Provisional Allotment / Registered Student, or with a released admission offer letter
--   Number of New Enrollments     = applications in Registered Student (status ACCEPTED, i.e. converted to student)
-- Academic periods are coded as <acad_year_start><term sequence>0 of the first term of the admitted batch, e.g. 2025-26 term 1 -> 202510;
-- batches with no term configured fall back to <batch>10. To be mapped (CHEDS Semester Code list)
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet.
-- MySQL 5.x compatible: no CTEs / window functions.
SELECT
    c.university_code                                                   AS `Institution Code`,          -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    COALESCE(
        (SELECT t.acad_year_start * 100 + t.sequence * 10               -- first regular term of the admitted batch (programme term preferred over all-programme term)
         FROM term t
         WHERE t.acad_year_start = sac.batch
           AND IFNULL(t.additional_term, 0) = 0
           AND (t.programme_id = sac.programme_id OR (t.all_programmes = 1 AND t.college_id = sac.college_id))
         ORDER BY (t.programme_id = sac.programme_id) DESC, t.starts
         LIMIT 1),
        sac.batch * 100 + 10)                                           AS `Academic Period`,
    pt.name                                                             AS `Degrees / Program Levels`,  -- Degree code to be mapped (KHDA Dict, e.g. BA)
    p.programme_name                                                    AS `Area of Specialization`,    -- To Be Checked: CIP code to be mapped per programme ('99' if not listed)
    COUNT(*)                                                            AS `Number of Applicants`,
    SUM(afs.status IN ('PROVISIONAL_ALLOTMENT', 'ACCEPTED')
        OR IFNULL(ol.has_offer, 0) = 1)                                 AS `Number of Admissions Offered`,
    SUM(afs.status = 'ACCEPTED')                                        AS `Number of New Enrollments`,
    DATE_FORMAT(MAX(GREATEST(s.modified_timestamp,
                             COALESCE(ol.last_modified, s.modified_timestamp))), '%Y-%m-%d') AS `Last Updated`
FROM student_admission_form_status s
JOIN student_admission_category sac   ON sac.id = s.student_admission_category_id
JOIN programme p                      ON p.programme_id = sac.programme_id
LEFT JOIN programme_types pt          ON pt.id = p.programme_type_id
LEFT JOIN admission_form_status afs   ON afs.id = s.status_id
LEFT JOIN college c                   ON c.college_id = sac.college_id
LEFT JOIN (
    -- applications for which an admission offer letter was released (accepted / rejected / expired imply it was released)
    SELECT ukid, student_admission_category_id, 1 AS has_offer, MAX(modified_timestamp) AS last_modified
    FROM admission_offer_letter
    WHERE status <> 'NOT_RELEASED'
    GROUP BY ukid, student_admission_category_id
) ol ON ol.ukid = s.ukid AND ol.student_admission_category_id = s.student_admission_category_id
GROUP BY c.college_id, c.university_code, c.college_name, `Academic Period`, pt.name, p.programme_id, p.programme_name
ORDER BY `Academic Period` DESC, `Degrees / Program Levels`, `Area of Specialization`;
