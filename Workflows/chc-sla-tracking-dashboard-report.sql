-- Module: CHC (Campus Help Centre) — SLA Tracking Dashboard (per category, e.g. Fire and Safety)
-- Ticket-level detail: nature of complaint, hold status, SLA status and turnaround vs SLA target.
-- Turnaround is measured across Work Centre 1 and Work Centre 2 only — tickets that get routed
-- through Work Centre 3 (hold/escalation) are excluded from SLA compliance and flagged as N/A - Hold,
-- per the SLA exclusion rule agreed in the contract. SLA target minutes below are NOT stored in any
-- table; they are fixed values from the contract and must be edited per category/nature of complaint.

-- === Parameters — set these per category tab before running ===
SET @service_id        = 0;                        -- chc_service.id for this category (e.g. Fire and Safety)
SET @wc1_id             = 0;                        -- chc_work_centre.id for Work Centre 1
SET @wc2_id             = 0;                        -- chc_work_centre.id for Work Centre 2
SET @wc3_id             = 0;                        -- chc_work_centre.id for Work Centre 3 (hold/escalation, excluded from SLA)
SET @nature_field_name  = 'Nature of Complaint';    -- chc_request_form_field.name that captures the complaint type

-- === Ticket-level detail (drives the "Ticket Detail" table + every card/chart on the dashboard) ===
WITH nature AS (
    SELECT crfv.request_id,
           COALESCE(crffeo.label, crfv.value_reference, crfv.value) AS nature_of_complaint
    FROM chc_request_form_field_value crfv
    JOIN chc_request_form_field crff
        ON crff.id = crfv.field_id AND crff.name = @nature_field_name
    LEFT JOIN chc_request_form_field_element_option crffeo ON crffeo.id = crfv.value
),
hold_flag AS (
    SELECT DISTINCT request_id, 1 AS kept_on_hold
    FROM chc_work_centre_request_action
    WHERE work_centre_id = @wc3_id
),
closure AS (
    SELECT wcra.request_id, MAX(wcra.created_on) AS closed_on
    FROM chc_work_centre_request_action wcra
    JOIN chc_work_centre_action wca ON wca.id = wcra.action_id
    WHERE wcra.work_centre_id IN (@wc1_id, @wc2_id)
      AND wca.is_termination_action = 1
    GROUP BY wcra.request_id
),
-- SLA target minutes per nature of complaint — hardcoded per contract, edit for this category
sla_targets AS (
    SELECT 'Fire in campus/quad/any location' AS nature_of_complaint, 5  AS target_minutes UNION ALL
    SELECT 'Fire outside campus boundary wall',                       5  UNION ALL
    SELECT 'Fire alarm & detection system',                           10 UNION ALL
    SELECT 'Barricade area / WIP signage',                            5
)
SELECT
    cr.id                                              AS request_id,
    n.nature_of_complaint,
    IF(hf.kept_on_hold = 1, 'Yes', 'No')                AS kept_on_hold,
    CASE
        WHEN hf.kept_on_hold = 1        THEN 'N/A - Hold'
        WHEN cr.status <> 'closed'      THEN 'Open'
        WHEN st.target_minutes IS NULL  THEN 'No SLA Defined'
        WHEN TIMESTAMPDIFF(MINUTE, cr.created_on, cl.closed_on) <= st.target_minutes THEN 'Followed'
        ELSE 'Not Followed'
    END                                                 AS sla_status,
    TIMESTAMPDIFF(MINUTE, cr.created_on, cl.closed_on)  AS turnaround_minutes,
    st.target_minutes                                   AS sla_target_minutes,
    cr.status                                            AS ticket_status,
    cr.created_on
FROM chc_request cr
LEFT JOIN nature n     ON n.request_id = cr.id
LEFT JOIN hold_flag hf ON hf.request_id = cr.id
LEFT JOIN closure cl   ON cl.request_id = cr.id
LEFT JOIN sla_targets st ON st.nature_of_complaint = n.nature_of_complaint
WHERE cr.service_id = @service_id
  AND cr.deleted = 0
ORDER BY cr.id;

-- === Summary cards: Total / Open / Closed / SLA Compliance % ===
-- Wrap the query above as `t` (e.g. save it as a view, or paste it inline) and run:
--
-- SELECT
--     COUNT(*)                                                                AS total_tickets,
--     SUM(ticket_status <> 'closed')                                          AS open_tickets,
--     SUM(ticket_status = 'closed')                                           AS closed_tickets,
--     ROUND(100 * SUM(sla_status = 'Followed')
--         / NULLIF(SUM(sla_status IN ('Followed', 'Not Followed')), 0), 0)    AS sla_compliance_pct
-- FROM t;

-- === "Closed Requests — SLA Followed vs Not Followed vs N/A (Hold)" ===
-- SELECT sla_status, COUNT(*) AS ticket_count
-- FROM t
-- WHERE ticket_status = 'closed'
-- GROUP BY sla_status;

-- === "SLA Tracking by Nature of Complaint" ===
-- SELECT nature_of_complaint, sla_status, COUNT(*) AS ticket_count
-- FROM t
-- WHERE ticket_status = 'closed'
-- GROUP BY nature_of_complaint, sla_status;
