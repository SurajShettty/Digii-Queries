-- TRANSPORT MODULE — DASHBOARD DATA SET
-- Grain: one row per student transport allotment.
-- Feed this flat table into the BI tool and pivot/group there for:
--   • Route-wise & pickup-point-wise headcount / utilization
--   • Department / programme / batch-wise distribution of transport users
--   • Fee collection: due vs paid vs pending, and % collected
--   • Defaulter list (Payment Status = 'Unpaid' / 'Partially Paid')
--   • Active vs Inactive/Cancelled allotment trend

SELECT
    ta.ukid,
    ua.registration_id                         AS "Registration ID",
    CONCAT(ua.f_name, ' ', ua.l_name)           AS "Name",
    a.email                                     AS "Email",
    ua.user_type                                AS "User Type",
    c.college_name                              AS "College",
    d.department_name                           AS "Department",
    p.programme_name                            AS "Programme",
    sp.year_of_joining                          AS "Batch",
    tr.name                                     AS "Route",
    tpp.name                                    AS "Pickup Point",
    ta.status                                   AS "Allotment Status",
    a.is_active                                 AS "Account Active",
    COALESCE(ex.due_amount, 0)                  AS "Due Amount",
    COALESCE(ex.paid_amount, 0)                 AS "Paid Amount",
    COALESCE(ex.pending_amount, 0)              AS "Pending Amount",
    CASE
        WHEN ex.due_amount IS NULL THEN 'No Dues Raised'
        WHEN COALESCE(ex.pending_amount, 0) <= 0 THEN 'Fully Paid'
        WHEN COALESCE(ex.paid_amount, 0) > 0 THEN 'Partially Paid'
        ELSE 'Unpaid'
    END                                          AS "Payment Status"
FROM
    transport_allotment ta
    LEFT JOIN user_attributes ua ON ua.ukid = ta.ukid
    LEFT JOIN authenticator a ON a.ukid = ta.ukid
    LEFT JOIN student_profile sp ON sp.ukid = ua.ukid
    LEFT JOIN programme p ON p.programme_id = sp.programme_id
    LEFT JOIN department d ON d.department_id = p.department_id
    LEFT JOIN college c ON c.college_id = ua.college_id
    LEFT JOIN transport_route_pickup_point trp ON trp.id = ta.option_id
    LEFT JOIN transport_route tr ON tr.id = trp.route_id
    LEFT JOIN transport_pickup_point tpp ON tpp.id = trp.pickup_point_id
    LEFT JOIN (
        SELECT
            d.id AS dues_id,
            d.student_ukid,
            df.due_amount,
            df.paid_amount,
            df.pending_amount
        FROM dues_v2 d
        LEFT JOIN dues_finance_v2 df ON df.dues_id = d.id
        WHERE d.entity = 'TRANSPORT_MANAGEMENT'
    ) ex ON ex.student_ukid = ta.ukid AND ex.dues_id = ta.due_id
-- Uncomment to restrict to active accounts / active allotments only:
-- WHERE a.is_active = 1
ORDER BY
    tr.name, tpp.name, ua.registration_id;


-- ─────────────────────────────────────────────────────────────
-- BONUS: quick KPI rollups if you want ready-made summary cards
-- instead of (or alongside) letting the BI tool aggregate the
-- detail set above.
-- ─────────────────────────────────────────────────────────────

-- Route-wise headcount & collection summary
-- SELECT
--     tr.name                                    AS "Route",
--     COUNT(*)                                    AS "Students Allotted",
--     SUM(CASE WHEN ta.status = 'ACTIVE' THEN 1 ELSE 0 END) AS "Active Allotments",
--     SUM(COALESCE(ex.due_amount, 0))             AS "Total Due",
--     SUM(COALESCE(ex.paid_amount, 0))            AS "Total Collected",
--     SUM(COALESCE(ex.pending_amount, 0))         AS "Total Pending"
-- FROM transport_allotment ta
-- LEFT JOIN transport_route_pickup_point trp ON trp.id = ta.option_id
-- LEFT JOIN transport_route tr ON tr.id = trp.route_id
-- LEFT JOIN (
--     SELECT d.id AS dues_id, d.student_ukid, df.due_amount, df.paid_amount, df.pending_amount
--     FROM dues_v2 d
--     LEFT JOIN dues_finance_v2 df ON df.dues_id = d.id
--     WHERE d.entity = 'TRANSPORT_MANAGEMENT'
-- ) ex ON ex.student_ukid = ta.ukid AND ex.dues_id = ta.due_id
-- GROUP BY tr.name
-- ORDER BY "Students Allotted" DESC;

-- Department-wise transport adoption
-- SELECT
--     d.department_name                          AS "Department",
--     COUNT(*)                                    AS "Students Using Transport"
-- FROM transport_allotment ta
-- LEFT JOIN user_attributes ua ON ua.ukid = ta.ukid
-- LEFT JOIN student_profile sp ON sp.ukid = ua.ukid
-- LEFT JOIN programme p ON p.programme_id = sp.programme_id
-- LEFT JOIN department d ON d.department_id = p.department_id
-- GROUP BY d.department_name
-- ORDER BY "Students Using Transport" DESC;
