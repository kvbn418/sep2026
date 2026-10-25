-- ══════════════════════════════════════════════════════════════════════
-- stg_products.sql12
-- Bronze staging model for products
-- Materialization: VIEW
-- Grain: one row per product_id
-- Source: RAW_DB.ECOMMERCE_RAW.PRODUCTS
--
-- What this model does:
--   1. Renames columns with prod_ prefix
--   2. Uppercases SKU for consistency
--   3. Calculates gross_margin_usd and gross_margin_pct
--   4. NULLIF prevents division by zero on zero-price products
-- ══════════════════════════════════════════════════════════════════════

{{ config(materialized='view', schema='bronze') }}

WITH source AS (
    -- Rename with src_ prefix to avoid keyword conflicts
    SELECT
        product_id,
        product_name     AS src_product_name,
        category         AS src_category,
        unit_price       AS src_unit_price,
        cost_price       AS src_cost_price,
        sku              AS src_sku,
        is_active        AS src_is_active,
        created_at       AS src_created_at,
        updated_at       AS src_updated_at,
        _fivetran_synced AS src_fivetran_synced
    FROM {{ source('ecommerce', 'products') }}
),

final AS (
    SELECT
        -- Primary key
        product_id,

        -- Name and category: trim whitespace
        TRIM(src_product_name)                      AS prod_product_name,
        TRIM(src_category)                          AS prod_category,

        -- SKU: uppercase for consistent formatting
        UPPER(TRIM(src_sku))                        AS prod_sku,

        -- Pricing
        src_unit_price                              AS prod_unit_price_usd,
        src_cost_price                              AS prod_cost_price_usd,

        -- Derived: gross margin in absolute USD and percentage
        -- ROUND to 2 decimal places for currency display
        ROUND(src_unit_price - src_cost_price, 2)   AS prod_gross_margin_usd,

        -- NULLIF(src_unit_price, 0) prevents division by zero
        -- for products with zero unit price (free samples etc)
        ROUND(
            (src_unit_price - src_cost_price)
            / NULLIF(src_unit_price, 0) * 100, 2
        )                                           AS prod_gross_margin_pct,

        -- Status: is this product still sold?
        src_is_active                               AS prod_is_active,

        -- Dates
        src_created_at::DATE                        AS prod_created_date,
        src_updated_at::TIMESTAMP_NTZ               AS prod_updated_at,
        src_fivetran_synced                         AS prod_source_loaded_at

    FROM source
)

SELECT
    product_id,
    prod_product_name,
    prod_category,
    prod_sku,
    prod_unit_price_usd,
    prod_cost_price_usd,
    prod_gross_margin_usd,
    prod_gross_margin_pct,
    prod_is_active,
    prod_created_date,
    prod_updated_at,
    prod_source_loaded_at
FROM final
