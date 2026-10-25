-- models/gold/dim_customers.sql
-- Layer  : Gold (dimension)
-- Grain  : One row per customer_id
-- Source : int_orders_enriched (silver)
-- Use    : BI tools, Tableau, joins in fct_orders

WITH enriched AS (

    SELECT * FROM {{ ref('int_orders_enriched') }}

),

-- Get one row per customer with their latest details
customer_base AS (

    SELECT DISTINCT
        customer_id,
        customer_first_name,
        customer_last_name,
        customer_full_name,
        customer_email,
        customer_country,
        customer_city

    FROM enriched

),

-- Aggregate order behaviour per customer
customer_orders AS (

    SELECT
        customer_id,
        COUNT(DISTINCT order_id)            AS total_orders,
        COUNT(DISTINCT
            CASE WHEN is_active_order
            THEN order_id END)              AS active_orders,
        COUNT(DISTINCT
            CASE WHEN is_delivered
            THEN order_id END)              AS delivered_orders,
        MIN(order_date)                     AS first_order_date,
        MAX(order_date)                     AS latest_order_date,
        SUM(line_total_usd)                 AS lifetime_revenue_usd,
        AVG(order_total_usd)                AS avg_order_value_usd,
        SUM(line_gross_profit_usd)          AS lifetime_gross_profit_usd

    FROM enriched
    GROUP BY customer_id

),

final AS (

    SELECT
        -- Keys
        cb.customer_id,

        -- Identity
        cb.customer_first_name,
        cb.customer_last_name,
        cb.customer_full_name,
        cb.customer_email,

        -- Location
        cb.customer_country,
        cb.customer_city,

        -- Order behaviour
        co.total_orders,
        co.active_orders,
        co.delivered_orders,
        co.first_order_date,
        co.latest_order_date,
        co.lifetime_revenue_usd,
        ROUND(co.avg_order_value_usd, 2)    AS avg_order_value_usd,
        co.lifetime_gross_profit_usd,

        -- Customer segment based on lifetime value
        CASE
            WHEN co.lifetime_revenue_usd >= 300 THEN 'platinum'
            WHEN co.lifetime_revenue_usd >= 150 THEN 'gold'
            WHEN co.lifetime_revenue_usd >= 50  THEN 'silver'
            ELSE 'bronze'
        END                                 AS customer_segment,

        -- Days since last order
        DATEDIFF('day',
            co.latest_order_date,
            CURRENT_DATE())                 AS days_since_last_order,

        -- Is this customer active (ordered in last 90 days)?
        CASE
            WHEN DATEDIFF('day',
                co.latest_order_date,
                CURRENT_DATE()) <= 90
            THEN TRUE
            ELSE FALSE
        END                                 AS is_active_customer

    FROM customer_base cb
    LEFT JOIN customer_orders co
        ON cb.customer_id = co.customer_id

)

SELECT
    customer_id,
    customer_first_name,
    customer_last_name,
    customer_full_name,
    customer_email,
    customer_country,
    customer_city,
    total_orders,
    active_orders,
    delivered_orders,
    first_order_date,
    latest_order_date,
    lifetime_revenue_usd,
    avg_order_value_usd,
    lifetime_gross_profit_usd,
    customer_segment,
    days_since_last_order,
    is_active_customer

FROM final