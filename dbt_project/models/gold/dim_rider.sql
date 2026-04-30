{{
    config(
        materialized = 'table',
        tags         = ['gold', 'dimension']
    )
}}

-- ─────────────────────────────────────────────────────────────────────────────
-- GOLD | dim_rider
-- Layer   : Dimension table — one row per rider
-- Depends : sl_food_delivery_orders  +  br_food_delivery_riders
--
-- Joins rider reference data with delivery performance metrics.
-- This dimension is unique to the food delivery domain and has no
-- equivalent in a traditional e-commerce project.
-- ─────────────────────────────────────────────────────────────────────────────

WITH rider_ref AS (

    SELECT
        rider_id,
        rider_name,
        city    AS base_city,
        vehicle
    FROM {{ ref('br_food_delivery_riders') }}

),

rider_performance AS (

    SELECT
        rider_id,
        COUNT(*)                                        AS total_deliveries,
        COUNT(*) FILTER (
            WHERE delivery_status = 'Delivered'
        )                                               AS successful_deliveries,
        COUNT(*) FILTER (
            WHERE delivery_status = 'Failed Delivery'
        )                                               AS failed_deliveries,
        COUNT(*) FILTER (
            WHERE delivery_status = 'Cancelled'
        )                                               AS cancelled_deliveries,
        ROUND(AVG(customer_rating)::NUMERIC, 2)         AS avg_customer_rating,
        ROUND(SUM(delivery_fee)::NUMERIC, 2)            AS total_delivery_fees_earned,
        COUNT(DISTINCT customer_id)                     AS unique_customers_served,
        MODE() WITHIN GROUP (ORDER BY city)             AS most_active_city,
        MIN(order_date)                                 AS first_delivery_date,
        MAX(order_date)                                 AS last_delivery_date

    FROM {{ ref('sl_food_delivery_orders') }}
    WHERE rider_id IS NOT NULL
    GROUP BY rider_id

),

final AS (

    SELECT
        r.rider_id,
        r.rider_name,
        r.base_city,
        r.vehicle,

        -- Performance metrics
        COALESCE(p.total_deliveries, 0)           AS total_deliveries,
        COALESCE(p.successful_deliveries, 0)      AS successful_deliveries,
        COALESCE(p.failed_deliveries, 0)          AS failed_deliveries,
        COALESCE(p.cancelled_deliveries, 0)       AS cancelled_deliveries,

        -- Success rate
        CASE
            WHEN COALESCE(p.total_deliveries, 0) > 0
            THEN ROUND(
                (p.successful_deliveries::NUMERIC / p.total_deliveries) * 100, 2
            )
            ELSE 0
        END                                       AS success_rate_pct,

        p.avg_customer_rating,
        COALESCE(p.total_delivery_fees_earned, 0) AS total_delivery_fees_earned,
        COALESCE(p.unique_customers_served, 0)    AS unique_customers_served,
        p.most_active_city,
        p.first_delivery_date,
        p.last_delivery_date,

        -- Rider tier based on success rate and volume
        CASE
            WHEN COALESCE(p.total_deliveries, 0) >= 50
                 AND COALESCE(p.avg_customer_rating, 0) >= 4.5  THEN 'Elite'
            WHEN COALESCE(p.total_deliveries, 0) >= 20
                 AND COALESCE(p.avg_customer_rating, 0) >= 3.5  THEN 'Experienced'
            WHEN COALESCE(p.total_deliveries, 0) >= 1           THEN 'Active'
            ELSE 'Inactive'
        END                                       AS rider_tier

    FROM rider_ref r
    LEFT JOIN rider_performance p USING (rider_id)

)

SELECT * FROM final
