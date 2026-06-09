-- Certificate Report
-- Lists all certificates issued to a given student (filtered by registration_id), showing
-- the certificate number, recipient name/type, certificate type, and the issue timestamp
-- converted to IST.
-- Per (student, template) it derives a version_no (chronological order) and a latest_flag
-- (1 for the most recently issued version), plus a published_flag (1 when the certificate
-- has been published to the student via ems_student_publish_certificate) and the name of
-- the user who requested/issued it.
-- Results are ordered by registration_id, certificate type, then version.
WITH certificate_data AS (
    SELECT
        t1.id AS certificate_number,
        t2.user_type,
        CONCAT(ua.f_name, ' ', ua.l_name) AS user_name,
        ua.registration_id,
        t2.certificate_type AS certificate,
        CONVERT_TZ(t1.created_timestamp, '+00:00', '+05:30') AS issued_at,

        ROW_NUMBER() OVER (
            PARTITION BY t1.ukid, t1.certificate_template_id
            ORDER BY t1.created_timestamp
        ) AS version_no,

        CASE
            WHEN ROW_NUMBER() OVER (
                PARTITION BY t1.ukid, t1.certificate_template_id
                ORDER BY t1.created_timestamp DESC
            ) = 1
            THEN 1
            ELSE 0
        END AS latest_flag,

        CASE
            WHEN sp.student_ukid IS NOT NULL
                 AND sp.is_published = 1
            THEN 1
            ELSE 0
        END AS published_flag,

        CONCAT(ua2.f_name, ' ', ua2.l_name) AS issued_by

    FROM ems_certificates t1
    LEFT JOIN ems_certificates_template t2
        ON t1.certificate_template_id = t2.id
    LEFT JOIN user_attributes ua
        ON ua.ukid = t1.ukid
    LEFT JOIN ems_student_publish_certificate sp
        ON sp.student_ukid = t1.ukid
       AND sp.template_id = t1.certificate_template_id
    LEFT JOIN user_attributes ua2
        ON ua2.ukid = t1.requested_by

    WHERE ua.registration_id = '23010001056'
)

SELECT *
FROM certificate_data
ORDER BY registration_id, certificate, version_no;