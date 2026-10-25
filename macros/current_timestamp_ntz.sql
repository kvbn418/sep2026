-- macros/current_timestamp_ntz.sql
-- Returns current timestamp in NTZ format (no timezone)
-- Avoids repeating CONVERT_TIMEZONE everywhere
-- Usage: {{ current_timestamp_ntz() }}

{% macro current_timestamp_ntz() %}

    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ

{% endmacro %}