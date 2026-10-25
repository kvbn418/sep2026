{% macro drop_schema(database, schema) %}
    {% set drop_sql %}
        DROP SCHEMA IF EXISTS {{ database }}.{{ schema }};
    {% endset %}
    {% do run_query(drop_sql) %}
    {{ log("Dropped schema: " ~ database ~ "." ~ schema, info=True) }}
{% endmacro %}