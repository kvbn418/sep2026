-- ══════════════════════════════════════════════════════════════════════
-- order_value_tier.sql
-- Business rule macro: categorises orders by value
--
-- Parameters:
--   amount_column: the column containing the order total
--   high: threshold for high tier (default $150)
--   medium: threshold for medium tier (default $75)
--
-- Usage (default thresholds):
--   {{ order_value_tier('o.ord_total_amount_usd') }} AS order_value_tier
--
-- Usage (custom thresholds):
--   {{ order_value_tier('amt', high=200, medium=100) }}
--
-- Returns: 'high', 'medium', or 'low'
-- ══════════════════════════════════════════════════════════════════════

{% macro order_value_tier(amount_column, high=150, medium=75) %}
    CASE
        WHEN {{ amount_column }} >= {{ high }}   THEN 'high'
        WHEN {{ amount_column }} >= {{ medium }} THEN 'medium'
        ELSE 'low'
    END
{% endmacro %}