{{
    config(
        materialized = 'table',
        tags         = ['gold', 'dimension']
    )
}}

-- ─────────────────────────────────────────────────────────────────────────────
-- GOLD | dim_customer
-- Layer   : Dimension table — one row per customer
-- Depends : sl_food_delivery_orders  +  br_food_delivery_customers
--
-- Enriches the cleaned orders with customer reference data and adds
-- behavioural summary columns computed from order history.
-- ─────────────────────────────────────────────────────────────────────────────

WITH customer_ref AS (

    SELECT
        customer_id,
        customer_name,
        city           AS home_city,
        phone,
        CAST(signup_date AS DATE) AS signup_date
    FROM {{ ref('br_food_delivery_customers') }}

),

order_summary AS (

    SELECT
        customer_id,
        COUNT(*)                                    AS total_orders,
        SUM(grand_total)                            AS lifetime_value,
        ROUND(AVG(grand_total)::NUMERIC, 2)         AS avg_order_value,
        ROUND(AVG(customer_rating)::NUMERIC, 2)     AS avg_rating_given,
        MIN(order_date)                             AS first_order_date,
        MAX(order_date)                             AS last_order_date,
        COUNT(*) FILTER (
            WHERE delivery_status = 'Delivered'
        )                                           AS delivered_orders,
        COUNT(*) FILTER (
            WHERE delivery_status = 'Cancelled'
        )                                           AS cancelled_orders,
        MODE() WITHIN GROUP (ORDER BY payment_method) AS preferred_payment,
        MODE() WITHIN GROUP (ORDER BY city)            AS most_ordered_from_city

    FROM {{ ref('sl_food_delivery_orders') }}
    GROUP BY customer_id

),

final AS (

    SELECT
        c.customer_id,
        c.customer_name,
        c.home_city,
        c.phone,
        c.signup_date,

        -- Order behaviour
        COALESCE(o.total_orders, 0)         AS total_orders,
        COALESCE(o.lifetime_value, 0)       AS lifetime_value,
        COALESCE(o.avg_order_value, 0)      AS avg_order_value,
        o.avg_rating_given,
        o.first_order_date,
        o.last_order_date,
        COALESCE(o.delivered_orders, 0)     AS delivered_orders,
        COALESCE(o.cancelled_orders, 0)     AS cancelled_orders,
        o.preferred_payment,
        o.most_ordered_from_city,

        -- Customer segment based on lifetime value
        CASE
            WHEN COALESCE(o.lifetime_value, 0) >= 10000 THEN 'VIP'
            WHEN COALESCE(o.lifetime_value, 0) >= 3000  THEN 'Regular'
            WHEN COALESCE(o.total_orders, 0)  >= 1      THEN 'New'
            ELSE 'Inactive'
        END                                 AS customer_segment

    FROM customer_ref c
    LEFT JOIN order_summary o USING (customer_id)

)

SELECT * FROM final
