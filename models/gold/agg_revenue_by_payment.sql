-- models/gold/agg_revenue_by_payment.sql
{{ config(materialized='table', schema='gold') }}

SELECT
    order_date,
    {{ pivot_payment_methods() }}
FROM {{ ref('stg_orders') }}
GROUP BY order_date
ORDER BY order_date