{{
    config(
        materialized = 'view',
        tags         = ['bronze', 'raw']
    )
}}

-- ─────────────────────────────────────────────────────────────────────────────
-- BRONZE | br_food_delivery_riders
-- Layer   : Raw ingestion — riders reference table
-- ─────────────────────────────────────────────────────────────────────────────

SELECT *
FROM {{ ref('food_delivery_riders') }}
