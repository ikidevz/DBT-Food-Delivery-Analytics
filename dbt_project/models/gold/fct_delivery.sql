{{ config(
    materialized = 'table',
    tags         = ['gold', 'fact']
) }}

-- ─────────────────────────────────────────────────────────────────────────────
-- GOLD | fct_delivery
-- Layer   : Fact table — one row per order event
-- Depends : sl_food_delivery_orders
--
-- Central fact table in the star schema.
-- Contains all measurable business events and foreign keys to dimensions.
-- ─────────────────────────────────────────────────────────────────────────────

WITH base AS (

    SELECT
        order_id,
        order_datetime,
        order_date,
        order_month,
        order_hour,
        order_day_of_week,

        customer_id,
        rider_id,
        restaurant_id,

        city,
        cuisine_type,

        item_count,
        order_total,
        delivery_fee,
        grand_total,
        payment_method,
        delivery_status,
        customer_rating

    FROM {{ ref('sl_food_delivery_orders') }}

),

final AS (

    SELECT
        -- ── Surrogate / Natural Keys ─────────────────────────────────────
        order_id,                    -- Degenerate dimension
        customer_id,                 -- FK → dim_customer
        rider_id,                    -- FK → dim_rider
        restaurant_id,               -- FK → dim_restaurant (we will add this)

        -- ── Date / Time Spine ─────────────────────────────────────────────
        order_datetime,
        order_date,
        order_month,
        order_hour,
        order_day_of_week,

        -- ── Degenerate Dimensions (low cardinality, useful for filtering) ──
        city,
        cuisine_type,
        payment_method,
        delivery_status,

        -- ── Measures (Facts) ──────────────────────────────────────────────
        item_count,
        ROUND(order_total::NUMERIC, 2)     AS order_total,
        ROUND(delivery_fee::NUMERIC, 2)    AS delivery_fee,
        ROUND(grand_total::NUMERIC, 2)     AS grand_total,
        customer_rating,

        -- ── Boolean Flags (highly recommended for BI tools) ───────────────
        (delivery_status = 'Delivered')       AS is_delivered,
        (delivery_status = 'Cancelled')       AS is_cancelled,
        (delivery_status = 'Failed Delivery') AS is_failed,
        (customer_rating IS NOT NULL)         AS is_rated,

        -- ── Business Segments ─────────────────────────────────────────────
        CASE
            WHEN order_hour BETWEEN 11 AND 13 THEN 'Lunch Rush'
            WHEN order_hour BETWEEN 17 AND 20 THEN 'Dinner Rush'
            ELSE 'Off-Peak'
        END                                   AS time_of_day_segment,

        CASE
            WHEN order_day_of_week IN ('Sat', 'Sun') THEN TRUE 
            ELSE FALSE 
        END                                   AS is_weekend,

        -- Optional: Add more useful flags if needed
        (order_total > 500)                   AS is_high_value_order

    FROM base

)

SELECT * FROM final