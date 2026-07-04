SELECT 
    t1.ukid,

    COALESCE(
        NULLIF(TRIM(MAX(CASE 
            WHEN t1.field_id = 61 THEN t1.value 
        END)), ''),
        'No Data'
    ) AS student_state,

    COALESCE(
        NULLIF(TRIM(MAX(CASE 
            WHEN t1.field_id = 177 THEN t1.value 
        END)), ''),
        'No Data'
    ) AS student_country,

    c.address AS college_address,

    CASE 
        WHEN NULLIF(TRIM(MAX(CASE 
            WHEN t1.field_id = 61 THEN t1.value 
        END)), '') IS NULL 
        THEN 'No Data'

        WHEN LOWER(c.address) LIKE CONCAT(
            '%',
            LOWER(TRIM(MAX(CASE 
                WHEN t1.field_id = 61 THEN t1.value 
            END))),
            '%'
        )
        THEN 'Same State'

        ELSE 'Different State'
    END AS state_match,

    CASE 
        WHEN NULLIF(TRIM(MAX(CASE 
            WHEN t1.field_id = 177 THEN t1.value 
        END)), '') IS NULL 
        THEN 'No Data'

        WHEN LOWER(c.address) LIKE CONCAT(
            '%',
            LOWER(TRIM(MAX(CASE 
                WHEN t1.field_id = 177 THEN t1.value 
            END))),
            '%'
        )
        THEN 'Same Country'

        ELSE 'Different Country'
    END AS country_match

FROM user_details_master_field_value t1

LEFT JOIN user_details_master_field t2 
    ON t2.id = t1.field_id

LEFT JOIN college c 
    ON c.college_id = t2.college_id

WHERE t1.field_id IN (61, 177)

GROUP BY 
    t1.ukid,
    c.address;