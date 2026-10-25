-- ══════════════════════════════════════════════════════════════════════
-- is_active_order.sql
-- Business rule macro: determines if an order is active
--
-- An order is active if it has NOT been cancelled.
-- Used in: int_orders_enriched, fct_orders
--
-- Usage: {{ is_active_order('o.ord_status') }} AS is_active_order
--
-- Returns: TRUE for PENDING, PROCESSING, SHIPPED, DELIVERED
--          FALSE for CANCELLED only
--
-- DRY principle: define the rule once here, use it in many models
-- If the definition of "active" changes, update only this macro
-- ══════════════════════════════════════════════════════════════════════

{% macro is_active_order(status_column) %}
    CASE
        WHEN {{ status_column }} = 'CANCELLED' THEN FALSE
        ELSE TRUE
    END
{% endmacro %}