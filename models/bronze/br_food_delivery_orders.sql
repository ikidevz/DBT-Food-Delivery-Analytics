{{
    config(
        materialized = 'view',
        tags         = ['bronze', 'raw']
    )
}}

-- ─────────────────────────────────────────────────────────────────────────────
-- BRONZE | br_food_delivery_orders
-- Layer   : Raw ingestion — no transformations, no filtering
-- Purpose : Expose the source CSV as a queryable view so downstream
--           Silver models always point to a single, stable reference.
--           If the source table name ever changes, only this file needs updating.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT *
FROM {{ ref('food_delivery_orders') }}
