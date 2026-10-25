-- ══════════════════════════════════════════════════════════════════════
-- int_orders_enriched.sql
-- Silver enriched orders model
-- Materialization: TABLE (physically stored — joins are expensive)
-- Grain: one row per order_item_id (19 rows from sample data)
-- Source: four Bronze VIEWs via ref()
--
-- What this model does:
--   1. Joins stg_orders + stg_customers + stg_order_items + stg_products
--   2. Brings all relevant columns into one wide table for Gold consumption
--   3. Applies business rule macros: is_active_order, order_value_tier
--   4. Derives: is_delivered, line_gross_profit_usd
--   5. Uses LEFT JOIN to preserve all order_items even if parent records missing
--
-- Why LEFT JOIN not INNER JOIN:
--   INNER JOIN silently drops rows where any join fails (orphaned items,
--   deleted products). LEFT JOIN keeps all rows visible for investigation.
-- ══════════════════════════════════════════════════════════════════════

{{ config(materialized='table', schema='silver') }}

-- CTE: load each Bronze model once and alias clearly
WITH orders      AS (SELECT * FROM {{ ref('stg_orders') }}),
     customers   AS (SELECT * FROM {{ ref('stg_customers') }}),
     order_items AS (SELECT * FROM {{ ref('stg_order_items') }}),
     products    AS (SELECT * FROM {{ ref('stg_products') }}),

joined AS (
    SELECT
        -- ── Keys ─────────────────────────────────────────────────────
        oi.order_item_id,
        oi.order_id,
        o.customer_id,
        oi.product_id,

        -- ── Order dates ───────────────────────────────────────────────
        o.order_date,
        o.shipped_date,
        o.delivered_date,

        -- ── Order status and payment ──────────────────────────────────
        o.ord_status                        AS order_status,
        o.ord_payment_method                AS payment_method,
        o.ord_currency                      AS currency,

        -- ── Shipping ─────────────────────────────────────────────────
        o.ord_shipping_country              AS shipping_country,
        o.ord_days_to_ship                  AS days_to_ship,
        o.ord_days_to_deliver               AS days_to_deliver,

        -- ── Customer details (denormalised for BI performance) ────────
        c.cust_first_name                   AS customer_first_name,
        c.cust_last_name                    AS customer_last_name,
        c.cust_full_name                    AS customer_full_name,
        c.cust_email                        AS customer_email,
        c.cust_country                      AS customer_country,
        c.cust_city                         AS customer_city,

        -- ── Product details (denormalised for BI performance) ─────────
        p.prod_product_name                 AS product_name,
        p.prod_category                     AS product_category,
        p.prod_sku                          AS product_sku,
        p.prod_is_active                    AS product_is_active,

        -- ── Line item amounts ─────────────────────────────────────────
        oi.item_quantity                    AS quantity,
        oi.item_unit_price_usd              AS unit_price_usd,
        oi.item_discount_amount_usd         AS discount_amount_usd,
        oi.item_line_total_usd              AS line_total_usd,

        -- ── Order-level amounts ───────────────────────────────────────
        o.ord_subtotal_amount_usd           AS order_subtotal_usd,
        o.ord_discount_amount_usd           AS order_discount_usd,
        o.ord_shipping_amount_usd           AS order_shipping_usd,
        o.ord_total_amount_usd              AS order_total_usd,

        -- ── Business rule macros ──────────────────────────────────────
        -- is_active_order: FALSE only for CANCELLED orders
        -- Defined in macros/is_active_order.sql
        {{ is_active_order('o.ord_status') }}             AS is_active_order,

        -- order_value_tier: high/medium/low based on order total
        -- Defined in macros/order_value_tier.sql
        -- Thresholds: high >= $150, medium >= $75, low < $75
        {{ order_value_tier('o.ord_total_amount_usd') }}  AS order_value_tier,

        -- ── Derived boolean flags ─────────────────────────────────────
        CASE
            WHEN o.ord_status = 'DELIVERED' THEN TRUE
            ELSE FALSE
        END                                 AS is_delivered,

        -- ── Cost and profitability ────────────────────────────────────
        p.prod_cost_price_usd               AS product_cost_usd,

        -- Gross profit = line revenue minus cost of goods sold
        -- COGS = cost_price * quantity (units sold)
        ROUND(
            oi.item_line_total_usd
            - (p.prod_cost_price_usd * oi.item_quantity), 2
        )                                   AS line_gross_profit_usd,

        -- ── Audit timestamps ─────────────────────────────────────────
        -- ord_updated_at used as watermark in fct_orders incremental filter
        o.ord_created_at                    AS order_created_at,
        o.ord_updated_at                    AS order_updated_at

    -- LEFT JOIN: preserve all order_items even if parent records are missing
    FROM order_items oi
    LEFT JOIN orders    o ON oi.order_id   = o.order_id
    LEFT JOIN customers c ON o.customer_id = c.customer_id
    LEFT JOIN products  p ON oi.product_id = p.product_id
)

SELECT * FROM joined