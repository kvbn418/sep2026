-- tests/assert_positive_order_revenue.sql
-- Returns rows only if the test FAILS
-- Zero rows returned = TEST PASSES
-- Any rows returned  = TEST FAILS

SELECT
    order_id,
    order_total_usd
FROM {{ ref('fct_orders') }}
WHERE order_total_usd < 0