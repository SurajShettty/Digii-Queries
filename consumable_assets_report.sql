-- Module: Asset Management — Consumable Assets Report (per product)
-- One row per consumable product with purchased / issued / returned / in-stock
-- quantities, stock value, reorder status and expiry position.
--
-- Schema:
--   asset_category         (ac)  -> type ('FIXED'/'CONSUMABLE'), parent_id
--   asset_product          (ap)  -> category_id, unit_of_measurement_id, location_id,
--                                   reorder_threshold, handle_expiry
--   asset                  (a)   -> one row per stock batch of a product:
--                                   quantity_purchased, quantity (current balance),
--                                   price, expiry_date, vendor_id
--   asset_allotment        (aa)  -> issue header (status provisional/confirmed/cancelled)
--   asset_batch_allotment  (aba) -> allotted_quantity / returned_quantity per batch
--
-- Notes:
--   A product is consumable when its category type = 'CONSUMABLE'.
--   asset.quantity is treated as the current on-hand balance of a batch and
--   asset.quantity_purchased as the quantity originally received.
--   Cancelled allotments are excluded from issued/returned totals.
--   net_consumed = issued - returned (consumables are rarely returned).
--   Products with no stock batches still appear (LEFT JOIN) with 0 quantities.
--   stock_status: OUT_OF_STOCK (0 on hand), REORDER (on hand <= reorder_threshold),
--   otherwise IN_STOCK.
--   Expired / near-expiry counts only apply when the product has handle_expiry = 1;
--   near-expiry window is 30 days — change INTERVAL below to adjust.

SELECT
    ac.name                                   AS category,
    pc.name                                   AS parent_category,
    ap.code                                   AS product_code,
    ap.name                                   AS product_name,
    uom.unit                                  AS unit,
    loc.name                                  AS store_location,
    COALESCE(st.batch_count, 0)               AS batch_count,
    COALESCE(st.qty_purchased, 0)             AS qty_purchased,
    COALESCE(iss.qty_issued, 0)               AS qty_issued,
    COALESCE(iss.qty_returned, 0)             AS qty_returned,
    COALESCE(iss.qty_issued, 0)
      - COALESCE(iss.qty_returned, 0)         AS net_consumed,
    COALESCE(st.qty_on_hand, 0)               AS qty_on_hand,
    ap.reorder_threshold,
    CASE
        WHEN COALESCE(st.qty_on_hand, 0) = 0                THEN 'OUT_OF_STOCK'
        WHEN ap.reorder_threshold IS NOT NULL
             AND st.qty_on_hand <= ap.reorder_threshold      THEN 'REORDER'
        ELSE 'IN_STOCK'
    END                                       AS stock_status,
    ROUND(COALESCE(st.purchase_value, 0), 2)  AS purchase_value,
    ROUND(COALESCE(st.on_hand_value, 0), 2)   AS on_hand_value,
    CASE WHEN ap.handle_expiry = 1 THEN COALESCE(st.qty_expired, 0) END      AS qty_expired,
    CASE WHEN ap.handle_expiry = 1 THEN COALESCE(st.qty_expiring_30d, 0) END AS qty_expiring_30d,
    CASE WHEN ap.handle_expiry = 1 THEN st.next_expiry_date END              AS next_expiry_date,
    st.last_stock_in_date,
    iss.last_issue_date
FROM asset_product ap
JOIN asset_category ac
    ON ac.id = ap.category_id
   AND ac.type = 'CONSUMABLE'
   AND ac.is_deleted = 0
LEFT JOIN asset_category pc       ON pc.id  = ac.parent_id
LEFT JOIN unit_of_measurement uom ON uom.id = ap.unit_of_measurement_id
LEFT JOIN infrastructure_version loc ON loc.id = ap.location_id
-- Stock-in / on-hand per product
LEFT JOIN (
    SELECT
        a.product_id,
        COUNT(*)                                        AS batch_count,
        SUM(COALESCE(a.quantity_purchased, a.quantity)) AS qty_purchased,
        SUM(COALESCE(a.quantity, 0))                    AS qty_on_hand,
        SUM(COALESCE(a.quantity_purchased, a.quantity) * COALESCE(a.price, 0)) AS purchase_value,
        SUM(COALESCE(a.quantity, 0) * COALESCE(a.price, 0))                    AS on_hand_value,
        SUM(CASE WHEN a.expiry_date < CURDATE() THEN a.quantity ELSE 0 END)    AS qty_expired,
        SUM(CASE WHEN a.expiry_date >= CURDATE()
                  AND a.expiry_date <  CURDATE() + INTERVAL 30 DAY
                 THEN a.quantity ELSE 0 END)                                   AS qty_expiring_30d,
        MIN(CASE WHEN a.expiry_date >= CURDATE() AND a.quantity > 0
                 THEN a.expiry_date END)                                       AS next_expiry_date,
        MAX(DATE(a.created_timestamp))                                         AS last_stock_in_date
    FROM asset a
    WHERE a.is_deleted = 0
    GROUP BY a.product_id
) st ON st.product_id = ap.id
-- Issues / returns per product
LEFT JOIN (
    SELECT
        a.product_id,
        SUM(COALESCE(aba.allotted_quantity, 0)) AS qty_issued,
        SUM(COALESCE(aba.returned_quantity, 0)) AS qty_returned,
        MAX(aa.allotment_date)                  AS last_issue_date
    FROM asset_batch_allotment aba
    JOIN asset a            ON a.id  = aba.asset_id AND a.is_deleted = 0
    JOIN asset_allotment aa ON aa.id = aba.asset_allotment_id
    WHERE COALESCE(aa.status, '') <> 'cancelled'
    GROUP BY a.product_id
) iss ON iss.product_id = ap.id
WHERE ap.is_deleted = 0
ORDER BY ac.name, ap.name;
