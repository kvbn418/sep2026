-- models/gold/fct_orders.sql
-- Layer             : Gold (fact)
-- Grain             : One row per order_id
-- Materialization   : incremental (merge strategy)
-- unique_key        : order_id
-- Incremental logic : only processes orders updated since last run
-- Source            : int_orders_enriched (silver)

{{
    config(
        materialized         = 'incremental',
        unique_key           = 'order_id',
        incremental_strategy = 'merge',
        on_schema_change     = 'sync_all_columns',
        cluster_by           = ['order_date'],
        tags                 = ['gold', 'incremental']
    )
}}

WITH enriched AS (

    SELECT * FROM {{ ref('int_orders_enriched') }}

    -- !! THIS IS THE CORE OF INCREMENTAL MODELS !!
    -- is_incremental() returns TRUE when the table already exists
    -- It returns FALSE on the very first run or after --full-refresh
    -- The filter tells dbt: only give me rows newer than what I already have

    {% if is_incremental() %}

        WHERE order_updated_at > (
            SELECT
                COALESCE(
                    MAX(order_updated_at),     -- latest row we already have
                    '1900-01-01'::TIMESTAMP    -- fallback for empty table
                )
            FROM {{ this }}                    -- {{ this }} = fct_orders itself
        )

    {% endif %}

),

order_aggregated AS (

    SELECT
        order_id,
        customer_id,
        order_date,
        shipped_date,
        delivered_date,
        order_status,
        payment_method,
        currency,
        shipping_country,
        days_to_ship,
        days_to_deliver,
        customer_full_name,
        customer_email,
        customer_country,
        customer_city,
        order_subtotal_usd,
        order_discount_usd,
        order_shipping_usd,
        order_total_usd,
        is_delivered,
        is_active_order,
        order_value_tier,
        order_created_at,
        order_updated_at,

        COUNT(order_item_id)                AS total_line_items,
        SUM(quantity)                       AS total_quantity,
        SUM(line_total_usd)                 AS total_line_revenue_usd,
        SUM(line_gross_profit_usd)          AS total_gross_profit_usd,
        SUM(discount_amount_usd)            AS total_item_discount_usd,
        ROUND(
            SUM(line_gross_profit_usd)
            / NULLIF(order_total_usd, 0) * 100, 2
        )                                   AS order_gross_margin_pct,
        MODE(product_category)              AS primary_product_category

    FROM enriched
    GROUP BY
        order_id, customer_id, order_date, shipped_date,
        delivered_date, order_status, payment_method, currency,
        shipping_country, days_to_ship, days_to_deliver,
        customer_full_name, customer_email, customer_country,
        customer_city, order_subtotal_usd, order_discount_usd,
        order_shipping_usd, order_total_usd, is_delivered,
        is_active_order, order_value_tier, order_created_at,
        order_updated_at

)

SELECT
    order_id,
    customer_id,
    order_date,
    shipped_date,
    delivered_date,
    order_status,
    payment_method,
    currency,
    shipping_country,
    days_to_ship,
    days_to_deliver,
    customer_full_name,
    customer_email,
    customer_country,
    customer_city,
    total_line_items,
    total_quantity,
    primary_product_category,
    order_subtotal_usd,
    order_discount_usd,
    order_shipping_usd,
    order_total_usd,
    total_gross_profit_usd,
    total_item_discount_usd,
    order_gross_margin_pct,
    is_delivered,
    is_active_order,
    order_value_tier,
    order_created_at,
    order_updated_at

FROM order_aggregated