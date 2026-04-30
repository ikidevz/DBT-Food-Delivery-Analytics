{{ config(
    materialized = 'table',
    tags = ['gold', 'dimension']
) }}

WITH restaurant_ref AS (
    SELECT
        restaurant_id,
        restaurant_name,
        cuisine_type,
        city AS base_city
    FROM {{ ref('br_food_delivery_restaurants') }}
),

restaurant_performance AS (
    SELECT
        restaurant_id,
        COUNT(*)                                   AS total_orders,
        COUNT(*) FILTER (WHERE delivery_status = 'Delivered') AS successful_orders,
        ROUND(SUM(grand_total)::NUMERIC, 2)        AS total_revenue,
        ROUND(AVG(grand_total)::NUMERIC, 2)        AS avg_order_value,
        ROUND(AVG(customer_rating)::NUMERIC, 2)    AS avg_rating_received,
        COUNT(DISTINCT customer_id)                AS unique_customers,
        MODE() WITHIN GROUP (ORDER BY city)        AS most_common_delivery_city,
        MIN(order_date)                            AS first_order_date,
        MAX(order_date)                            AS last_order_date
    FROM {{ ref('sl_food_delivery_orders') }}
    GROUP BY restaurant_id
)

SELECT
    r.restaurant_id,
    r.restaurant_name,
    r.cuisine_type,
    r.base_city,

    COALESCE(p.total_orders, 0)          AS total_orders,
    COALESCE(p.successful_orders, 0)     AS successful_orders,
    COALESCE(p.total_revenue, 0)         AS total_revenue,
    COALESCE(p.avg_order_value, 0)       AS avg_order_value,
    p.avg_rating_received,
    COALESCE(p.unique_customers, 0)      AS unique_customers,
    p.most_common_delivery_city,
    p.first_order_date,
    p.last_order_date,

    -- Restaurant tier
    CASE
        WHEN COALESCE(p.total_orders, 0) >= 30 AND COALESCE(p.avg_rating_received, 0) >= 4.5 THEN 'Top Rated'
        WHEN COALESCE(p.total_orders, 0) >= 15 THEN 'Popular'
        WHEN COALESCE(p.total_orders, 0) >= 1  THEN 'Active'
        ELSE 'New / Inactive'
    END AS restaurant_tier

FROM restaurant_ref r
LEFT JOIN restaurant_performance p USING (restaurant_id);