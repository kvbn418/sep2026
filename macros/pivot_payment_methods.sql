-- macros/pivot_payment_methods.sql
-- Dynamically pivots payment methods to columns
-- No need to hardcode the list — reads from the table at compile time
-- Usage: {{ pivot_payment_methods() }}

{% macro pivot_payment_methods() %}

    {% set payment_methods = dbt_utils.get_column_values(
        table=ref('stg_orders'),
        column='ord_payment_method'
    ) %}

    {% for method in payment_methods %}
        SUM(CASE
            WHEN ord_payment_method = '{{ method }}'
            THEN ord_total_amount_usd
            ELSE 0
        END) AS {{ method | replace('-','_') }}_revenue_usd
        {% if not loop.last %},{% endif %}
    {% endfor %}

{% endmacro %}