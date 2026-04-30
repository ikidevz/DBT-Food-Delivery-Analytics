{{
    config(
        materialized = 'view',
        tags         = ['bronze', 'raw']
    )
}}

-- ─────────────────────────────────────────────────────────────────────────────
-- BRONZE | br_food_delivery_customers
-- Layer   : Raw ingestion — customers reference table
-- ─────────────────────────────────────────────────────────────────────────────

SELECT *
FROM {{ ref('food_delivery_customers') }}
