{{
    config(
        materialized = 'table',
        tags         = ['silver', 'cleaned']
    )
}}

-- ─────────────────────────────────────────────────────────────────────────────
-- SILVER | sl_food_delivery_orders
-- Layer   : Cleaned, validated, deduplicated
-- Depends : br_food_delivery_orders
--
-- Data quality rules applied:
--   1. Drop rows where customer_id or rider_id is NULL
--   2. Reject orders with a future order_datetime
--   3. Clamp negative order_total → 0  (flagged as data error)
--   4. Clamp zero / negative item_count → 1
--   5. Clamp negative delivery_fee → 0
--   6. Map unknown cities → 'Unknown'
--   7. Deduplicate on order_id — keep the most recent record
--   8. Derive grand_total = order_total + delivery_fee
--   9. Extract date-parts for easier downstream aggregation
-- ─────────────────────────────────────────────────────────────────────────────

WITH validated AS (

    SELECT
        order_id,
        CAST(order_datetime AS TIMESTAMP)                          AS order_datetime,
        customer_id,
        rider_id,
        restaurant_id,

        -- City guard: only accept known PH delivery cities
        CASE
            WHEN city IN (
                'Davao', 'Cebu', 'Manila', 'Quezon City',
                'Iloilo', 'Cagayan de Oro', 'Zamboanga', 'Bacolod'
            ) THEN city
            ELSE 'Unknown'
        END                                                         AS city,

        cuisine_type,

        -- item_count must be ≥ 1
        CASE
            WHEN CAST(item_count AS INT) > 0 THEN CAST(item_count AS INT)
            ELSE 1
        END                                                         AS item_count,

        -- order_total must be ≥ 0
        CASE
            WHEN CAST(order_total AS NUMERIC) > 0
                THEN CAST(order_total AS NUMERIC)
            ELSE 0
        END                                                         AS order_total,

        -- delivery_fee must be ≥ 0
        CASE
            WHEN CAST(delivery_fee AS NUMERIC) >= 0
                THEN CAST(delivery_fee AS NUMERIC)
            ELSE 0
        END                                                         AS delivery_fee,

        payment_method,
        delivery_status,

        -- rating may legitimately be NULL (customer didn't rate)
        CASE
            WHEN CAST(customer_rating AS NUMERIC) BETWEEN 1.0 AND 5.0
                THEN CAST(customer_rating AS NUMERIC)
            ELSE NULL
        END                                                         AS customer_rating

    FROM {{ ref('br_food_delivery_orders') }}
    WHERE
        customer_id   IS NOT NULL
        AND rider_id  IS NOT NULL
        AND CAST(order_datetime AS TIMESTAMP) <= CURRENT_TIMESTAMP

),

deduplicated AS (

    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY order_datetime DESC
        ) AS rn

    FROM validated

),

final AS (

    SELECT
        order_id,
        order_datetime,

        -- Convenient date-part columns for Gold aggregations
        CAST(order_datetime AS DATE)                                AS order_date,
        DATE_TRUNC('month', order_datetime)::DATE                   AS order_month,
        EXTRACT(HOUR FROM order_datetime)::INT                      AS order_hour,
        TO_CHAR(order_datetime, 'Dy')                               AS order_day_of_week,

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

SELECT * FROM final
