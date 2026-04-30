{{
    config(
        materialized = 'table',
        tags         = ['gold', 'fact']
    )
}}

-- ─────────────────────────────────────────────────────────────────────────────
-- GOLD | fct_delivery
-- Layer   : Fact table — one row per completed order transaction
-- Depends : sl_food_delivery_orders
--
-- This is the central fact table of the food delivery warehouse.
-- It holds all measurable events (order amounts, fees, ratings) and
-- links to every dimension: customer, rider, restaurant, city, date.
--
-- Columns:
--   Surrogate keys  — for joining to dimension tables
--   Degenerate dims — order_id, delivery_status (stored on fact)
--   Measures        — order_total, delivery_fee, grand_total, item_count,
--                     customer_rating
--   Date spine      — order_date, order_month, order_hour, order_day_of_week
--   Derived flags   — is_delivered, is_cancelled, is_rated, peak_hour_flag
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
        -- ── Identifiers ──────────────────────────────────────────────────
        order_id,
        customer_id,
        rider_id,
        restaurant_id,

        -- ── Date spine ───────────────────────────────────────────────────
        order_datetime,
        order_date,
        order_month,
        order_hour,
        order_day_of_week,

        -- ── Dimensions stored on fact ─────────────────────────────────────
        city,
        cuisine_type,
        payment_method,
        delivery_status,

        -- ── Measures ─────────────────────────────────────────────────────
        item_count,
        ROUND(order_total::NUMERIC, 2)   AS order_total,
        ROUND(delivery_fee::NUMERIC, 2)  AS delivery_fee,
        ROUND(grand_total::NUMERIC, 2)   AS grand_total,
        customer_rating,

        -- ── Boolean flags (useful for BI tool filters) ────────────────────
        CASE WHEN delivery_status = 'Delivered'       THEN TRUE ELSE FALSE END  AS is_delivered,
        CASE WHEN delivery_status = 'Cancelled'       THEN TRUE ELSE FALSE END  AS is_cancelled,
        CASE WHEN delivery_status = 'Failed Delivery' THEN TRUE ELSE FALSE END  AS is_failed,
        CASE WHEN customer_rating IS NOT NULL         THEN TRUE ELSE FALSE END  AS is_rated,

        -- Peak hour: lunch 11-13, dinner 17-20
        CASE
            WHEN order_hour BETWEEN 11 AND 13 THEN 'Lunch Rush'
            WHEN order_hour BETWEEN 17 AND 20 THEN 'Dinner Rush'
            ELSE 'Off-Peak'
        END                                                                     AS time_of_day_segment,

        -- Weekend flag
        CASE
            WHEN order_day_of_week IN ('Sat', 'Sun') THEN TRUE ELSE FALSE
        END                                                                     AS is_weekend

    FROM base

)

SELECT * FROM final
