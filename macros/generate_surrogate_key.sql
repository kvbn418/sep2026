-- macros/generate_surrogate_key.sql
-- Generates an MD5 surrogate key from one or more columns
-- Used in Gold layer fact tables as a stable primary key
-- Usage: {{ generate_surrogate_key(['order_id', 'product_id']) }}

{% macro generate_surrogate_key(field_list) %}

    MD5(
        COALESCE(CAST({{ field_list | join(" || '-' || COALESCE(CAST(") }} AS VARCHAR), '')
        {% for field in field_list %}
            {% if not loop.first %} AS VARCHAR), '') {% endif %}
        {% endfor %}
    )

{% endmacro %}