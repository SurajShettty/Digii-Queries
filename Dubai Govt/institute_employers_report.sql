-- Institute - Employers report (CHEDS/KHDA format).
-- One row per employer contact person (placement_organization_contact) of each active placement organisation, per academic year (taken from the placement cycles the organisation took part in).
-- Organisations with no contact person are still listed (employer name/position/email will be NULL).
-- Columns marked "Enhancement Required" / "To Be Checked" have no source field yet and are returned as NULL.
SELECT DISTINCT                                                         -- cycles mapping to the same academic year collapse to one row
    c.university_code                                                   AS `Institution Code`,      -- CHEDS institution code to be mapped (KHDA Dict)
    c.college_name                                                      AS `Institution Name`,
    -- Academic year as YYYYyy from the placement cycle dates (start year + end year, e.g. 2025-04-01..2026-06-30 -> 202526).
    -- NULL when the organisation has no job/bank entry in any placement cycle. To be mapped (KHDA Dict)
    YEAR(pcy.start_date) * 100 + MOD(YEAR(COALESCE(pcy.end_date, pcy.start_date + INTERVAL 1 YEAR)), 100) AS `Academic Year`,
    NULLIF(TRIM(pc.contact_person), '')                                 AS `Name of the employer`,
    NULLIF(TRIM(pc.designation), '')                                    AS `Position`,
    NULL                                                                AS `Sector`,                -- Enhancement Required (Public/Private not captured)
    COALESCE(ps.name, s.name, po.type)                                  AS `Industry`,              -- Industry code to be mapped (KHDA Dict)
    TRIM(po.name)                                                       AS `Company Name`,
    NULL                                                                AS `Location_Country`,      -- Enhancement Required (only city-level head_office_location exists)
    NULL                                                                AS `Location_Emirate`,      -- Enhancement Required
    NULLIF(TRIM(pc.email_id), '')                                       AS `Email`,
    COALESCE(NULLIF(TRIM(pc.contact_number), ''),
             NULLIF(TRIM(pc.landline_number), ''),
             NULLIF(TRIM(po.head_office_contact), ''))                  AS `Phone (Optional)`,
    DATE_FORMAT(GREATEST(po.modified_timestamp,
                         COALESCE(pc.modified_timestamp, po.modified_timestamp)), '%Y-%m-%d') AS `Last Updated`
FROM placement_organization po
LEFT JOIN (
    -- placement cycles in which the organisation posted a job or has a bank entry
    SELECT organization_id, placement_cycle AS placement_cycle_id
    FROM placement_job
    WHERE IFNULL(is_deleted, 0) = 0 AND placement_cycle IS NOT NULL
    UNION
    SELECT organisation_id, placement_cycle_id
    FROM placement_organisation_bank
) poc ON poc.organization_id = po.id
LEFT JOIN placement_cycle pcy               ON pcy.id = poc.placement_cycle_id
LEFT JOIN placement_organization_contact pc ON pc.organization_id = po.id AND IFNULL(pc.deleted, 0) = 0
LEFT JOIN placement_organization_sector s   ON s.id = po.sector_id
LEFT JOIN placement_organization_sector ps  ON ps.id = s.parent_id
LEFT JOIN college c                         ON c.college_id = po.college_id
WHERE IFNULL(po.is_deleted, 0) = 0
  AND po.organisation_status = 'ACTIVE'
ORDER BY `Academic Year` DESC, `Company Name`, `Name of the employer`;
