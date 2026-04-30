{{ config(
    materialized = 'view',
    tags = ['bronze', 'raw']
) }}

SELECT *
FROM {{ ref('food_delivery_restaurants') }}