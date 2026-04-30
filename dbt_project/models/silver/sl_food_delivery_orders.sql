{{ config(
    materialized = 'table',
    tags         = ['silver', 'cleaned']
) }}

-- ─────────────────────────────────────────────────────────────────────────────
-- SILVER | sl_food_delivery_orders
-- Layer   : Cleansed, standardized, and deduplicated orders
-- Purpose : Single source of truth for clean order data
--           All Gold models (fct_delivery, dim_customer, dim_rider, dim_restaurant) 
--           should read from this table.
-- ─────────────────────────────────────────────────────────────────────────────

WITH source AS (

    SELECT *
    FROM {{ ref('br_food_delivery_orders') }}

),

validated AS (

    SELECT
        order_id,
        
        -- Timestamp cleaning
        CAST(order_datetime AS TIMESTAMP) AS order_datetime,

        -- Foreign Keys - Core cleaning
        NULLIF(TRIM(customer_id), '')     AS customer_id,
        NULLIF(TRIM(rider_id), '')        AS rider_id,
        NULLIF(TRIM(restaurant_id), '')   AS restaurant_id,

        -- Location & Category
        CASE 
            WHEN UPPER(TRIM(city)) IN ('DAVAO', 'CEBU', 'MANILA', 'QUEZON CITY', 
                                      'ILOILO', 'CAGAYAN DE ORO', 'ZAMBOANGA', 'BACOLOD') 
            THEN TRIM(city)
            ELSE 'Unknown' 
        END AS city,

        TRIM(cuisine_type) AS cuisine_type,

        -- Numeric cleaning with sensible defaults
        GREATEST(COALESCE(CAST(item_count AS INTEGER), 1), 1)        AS item_count,
        
        GREATEST(COALESCE(CAST(order_total AS NUMERIC), 0), 0)       AS order_total,
        
        GREATEST(COALESCE(CAST(delivery_fee AS NUMERIC), 0), 0)      AS delivery_fee,

        -- Payment and Status (standardized)
        TRIM(payment_method)     AS payment_method,
        TRIM(delivery_status)    AS delivery_status,

        -- Rating validation (allow NULL - this is normal)
        CASE 
            WHEN CAST(customer_rating AS NUMERIC) BETWEEN 1.0 AND 5.0 
                THEN ROUND(CAST(customer_rating AS NUMERIC), 1)
            ELSE NULL 
        END AS customer_rating

    FROM source

    -- Rule: Drop clearly invalid rows
    WHERE customer_id IS NOT NULL 
      AND rider_id IS NOT NULL
      AND restaurant_id IS NOT NULL
      AND CAST(order_datetime AS TIMESTAMP) <= CURRENT_TIMESTAMP

),

deduplicated AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id 
            ORDER BY order_datetime DESC, 
                     order_total DESC   -- secondary sort for determinism
        ) AS rn
    FROM validated

),

final AS (

    SELECT
        order_id,
        order_datetime,

        -- Derived date parts (computed once here)
        CAST(order_datetime AS DATE)                                AS order_date,
        DATE_TRUNC('month', order_datetime)::DATE                   AS order_month,
        EXTRACT(HOUR FROM order_datetime)::SMALLINT                 AS order_hour,
        TO_CHAR(order_datetime, 'Dy')                               AS order_day_of_week,
        TO_CHAR(order_datetime, 'Month')                            AS order_month_name,

        customer_id,
        rider_id,
        restaurant_id,
        city,
        cuisine_type,

        item_count,
        order_total,
        delivery_fee,
        order_total + delivery_fee                                  AS grand_total,

        payment_method,
        delivery_status,
        customer_rating

    FROM deduplicated
    WHERE rn = 1

)

SELECT * FROM final;