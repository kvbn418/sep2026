-- ══════════════════════════════════════════════════════════════════════
-- stg_order_items.sql
-- Bronze staging model for order line items
-- Materialization: VIEW
-- Grain: one row per order_item_id
-- Source: RAW_DB.ECOMMERCE_RAW.ORDER_ITEMS
--
-- What this model does:
--   1. Renames columns with item_ prefix
--   2. Calculates effective unit price (line_total / quantity)
--   3. NULLIF prevents division by zero on zero-quantity rows
-- ══════════════════════════════════════════════════════════════════════

{{ config(materialized='view', schema='bronze') }}

WITH source AS (
    SELECT
        order_item_id,
        order_id,
        product_id,
        quantity         AS src_quantity,
        unit_price       AS src_unit_price,
        discount_amount  AS src_discount_amount,
        line_total       AS src_line_total,
        created_at       AS src_created_at,
        _fivetran_synced AS src_fivetran_synced
    FROM {{ source('ecommerce', 'order_items') }}
),

final AS (
    SELECT
        -- Primary and foreign keys
        order_item_id,
        order_id,
        product_id,

        -- Quantities and pricing
        src_quantity                                AS item_quantity,
        src_unit_price                              AS item_unit_price_usd,
        src_discount_amount                         AS item_discount_amount_usd,

        -- Line total: pre-calculated in source as (unit_price * qty) - discount
        src_line_total                              AS item_line_total_usd,

        -- Derived: effective unit price after discount
        -- NULLIF prevents division by zero for zero-quantity correction rows
        ROUND(
            src_line_total / NULLIF(src_quantity, 0), 2
        )                                           AS item_effective_unit_price_usd,

        -- Timestamps
        src_created_at::TIMESTAMP_NTZ               AS item_created_at,
        src_fivetran_synced                         AS item_source_loaded_at

    FROM source
)

SELECT
    order_item_id,
    order_id,
    product_id,
    item_quantity,
    item_unit_price_usd,
    item_discount_amount_usd,
    item_line_total_usd,
    item_effective_unit_price_usd,
    item_created_at,
    item_source_loaded_at
FROM final