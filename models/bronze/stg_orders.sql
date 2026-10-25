-- ══════════════════════════════════════════════════════════════════════
-- stg_orders.sql
-- Bronze staging model for orders
-- Materialization: VIEW
-- Grain: one row per order_id
-- Source: RAW_DB.ECOMMERCE_RAW.ORDERS
--
-- What this model does:
--   1. Renames columns with ord_ prefix
--   2. Uppercases status and currency for consistency
--   3. Lowercases payment_method for consistency
--   4. Calculates days_to_ship and days_to_deliver
--   5. NULL days = order not yet shipped/delivered (expected for pending orders)
-- ══════════════════════════════════════════════════════════════════════

{{ config(materialized='view', schema='bronze') }}

WITH source AS (
    SELECT
        order_id,
        customer_id,
        order_date,
        shipped_date,
        delivered_date,
        status           AS src_status,
        shipping_address AS src_shipping_address,
        shipping_country AS src_shipping_country,
        subtotal_amount  AS src_subtotal_amount,
        discount_amount  AS src_discount_amount,
        shipping_amount  AS src_shipping_amount,
        total_amount     AS src_total_amount,
        currency         AS src_currency,
        payment_method   AS src_payment_method,
        created_at       AS src_created_at,
        updated_at       AS src_updated_at,
        _fivetran_synced AS src_fivetran_synced
    FROM {{ source('ecommerce', 'orders') }}
),

final AS (
    SELECT
        -- Primary and foreign keys
        order_id,
        customer_id,

        -- Dates: kept as DATE type from source
        order_date,
        shipped_date,
        delivered_date,

        -- Status: uppercase for consistent comparison in downstream models
        -- e.g. WHERE ord_status = 'DELIVERED' works regardless of source casing
        UPPER(TRIM(src_status))             AS ord_status,

        -- Shipping
        TRIM(src_shipping_address)          AS ord_shipping_address,
        TRIM(src_shipping_country)          AS ord_shipping_country,

        -- Financial amounts: kept in USD, renamed for clarity
        src_subtotal_amount                 AS ord_subtotal_amount_usd,
        src_discount_amount                 AS ord_discount_amount_usd,
        src_shipping_amount                 AS ord_shipping_amount_usd,
        src_total_amount                    AS ord_total_amount_usd,

        -- Currency: uppercase (USD, EUR, GBP)
        UPPER(TRIM(src_currency))           AS ord_currency,

        -- Payment method: lowercase (credit_card, paypal, bank_transfer)
        LOWER(TRIM(src_payment_method))     AS ord_payment_method,

        -- Derived: fulfilment speed metrics
        -- NULL when shipped_date or delivered_date is NULL (order not yet shipped/delivered)
        -- This is expected for PENDING, PROCESSING, SHIPPED status orders
        DATEDIFF(day, order_date, shipped_date)   AS ord_days_to_ship,
        DATEDIFF(day, order_date, delivered_date) AS ord_days_to_deliver,

        -- Timestamps for incremental model watermark
        src_created_at::TIMESTAMP_NTZ       AS ord_created_at,
        src_updated_at::TIMESTAMP_NTZ       AS ord_updated_at,
        src_fivetran_synced                 AS ord_source_loaded_at

    FROM source
)

SELECT
    order_id,
    customer_id,
    order_date,
    shipped_date,
    delivered_date,
    ord_status,
    ord_shipping_address,
    ord_shipping_country,
    ord_subtotal_amount_usd,
    ord_discount_amount_usd,
    ord_shipping_amount_usd,
    ord_total_amount_usd,
    ord_currency,
    ord_payment_method,
    ord_days_to_ship,
    ord_days_to_deliver,
    ord_created_at,
    ord_updated_at,
    ord_source_loaded_at
FROM final