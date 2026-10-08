-- Event Participant Report
-- One row per registered/pending participant of an event, with student academic details,
-- latest payment order and the event's custom required-detail answers pivoted into columns.
-- Replaces the per-participant N+1 lookups in EventParticipantDaoV2 / EventParticipationStatusDao /
-- PaymentOrderDao.getOrderDetailsByEntity / EventRequiredDetailsValuesDao with a single query.
--
-- Notes:
--   Set @event_id before running.
--   Reg ID: event_participant.institution_id (registration number entered at sign-up),
--           falling back to user_attributes.registration_id for logged-in students.
--   Institution Name: event_participant.institution_name, else the "Institution/Institute Name"
--           required-detail answer, else the participant's college.
--   Payment: payment_order rows with entity = 'event' and entity_id = event_participant.id;
--            only the latest order (max id) per participant is shown.
--   Received By: payment_order.receiver (offline collections), else the user in paid_by.
--   Required details are pivoted by field_name (LIKE match) since labels vary per event
--   (e.g. "Mobile No" / "Phone Number", "Aadhar Num" / "Institution Identity Card").
--   Times are converted from UTC to IST.

SET @event_id = 0;

SELECT
    COALESCE(ep.institution_id, ua.registration_id, '-')   AS `Reg ID`,
    ep.name                                                 AS `Name`,
    ep.email                                                AS `Email`,
    ep.phone                                                AS `Phone no.`,
    COALESCE(ep.ticket_id, '-')                             AS `Ticket ID`,
    COALESCE(ep.institution_name, rd.institution_name, c.college_name, '-') AS `Institution Name`,
    COALESCE(sp.year_of_joining, '-')                       AS `Batch Year`,
    COALESCE(p.programme_name, '-')                         AS `Programme`,
    COALESCE(d.department_name, '-')                        AS `Department`,
    COALESCE(ps.programme_section_name, '-')                AS `Section`,
    COALESCE(po.mode, ep.payment_mode, ep.payment_modes, '-') AS `Payment Mode`,
    COALESCE(po.status, '-')                                AS `Payment Status`,
    COALESCE(pg.gateway, '-')                               AS `Payment Gateway`,
    COALESCE(po.gateway_transaction_id, '-')                AS `Transaction ID`,
    COALESCE(DATE_FORMAT(ADDTIME(po.created_timestamp, '05:30:00'), '%d-%m-%Y %H:%i'), '-') AS `Transaction Date Time`,
    COALESCE(NULLIF(po.receiver, ''), CONCAT(rb.f_name, ' ', rb.l_name), '-') AS `Received By`,
    COALESCE(eps.status, '-')                               AS `Event Status`,
    COALESCE(rd.phone, '-')                                 AS `Phone`,
    COALESCE(rd.program_interested, '-')                    AS `Program Intrested`,
    COALESCE(rd.govt_id_card, '-')                          AS `Gover ID card`
FROM event_participant ep
LEFT JOIN event_participation_status eps ON eps.id = ep.participation_status_id
LEFT JOIN user_attributes ua            ON ua.ukid = ep.ukid
LEFT JOIN college c                     ON c.college_id = ua.college_id
LEFT JOIN student_profile sp            ON sp.ukid = ep.ukid
LEFT JOIN programme p                   ON p.programme_id = sp.programme_id
LEFT JOIN department d                  ON d.department_id = sp.department_id
LEFT JOIN programme_section ps          ON ps.programme_section_id = sp.section_id
-- latest payment order per participant
LEFT JOIN (
    SELECT entity_id, MAX(id) AS id
    FROM payment_order
    WHERE entity = 'event'
    GROUP BY entity_id
) lpo                                   ON lpo.entity_id = ep.id
LEFT JOIN payment_order po              ON po.id = lpo.id
LEFT JOIN payment_gateway pg            ON pg.id = po.payment_gateway_id
LEFT JOIN user_attributes rb            ON rb.ukid = po.paid_by
-- required-detail answers pivoted to one row per participant
LEFT JOIN (
    SELECT
        v.participant_id,
        MAX(CASE WHEN rq.field_name LIKE '%phone%' OR rq.field_name LIKE '%mobile%' THEN v.field_value END) AS phone,
        MAX(CASE WHEN rq.field_name LIKE '%program%'                                THEN v.field_value END) AS program_interested,
        MAX(CASE WHEN rq.field_name LIKE '%gov%' OR rq.field_name LIKE '%aadha%'
                   OR rq.field_name LIKE '%identity%' OR rq.field_name LIKE '%id card%' THEN v.field_value END) AS govt_id_card,
        MAX(CASE WHEN rq.field_name LIKE 'institut% name'                           THEN v.field_value END) AS institution_name
    FROM event_required_details rq
    JOIN event_required_details_values v
      ON v.required_field_id = rq.id
     AND v.event_id = rq.event_id
    WHERE rq.event_id = @event_id
    GROUP BY v.participant_id
) rd                                    ON rd.participant_id = ep.id
WHERE ep.event_id = @event_id
  AND ep.registration_status IN ('registered', 'pending')
ORDER BY ep.id;
