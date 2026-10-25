-- ══════════════════════════════════════════════════════════════════════
-- generate_schema_name.sql
-- Overrides dbt default schema naming behaviour
--
-- DEFAULT dbt behaviour (without this macro):
--   final_schema = target_schema + '_' + custom_schema
--   Result: SF_DBT_TABLEAU_BRONZE, SF_DBT_TABLEAU_SILVER (undesirable in dev)
--
-- AFTER this override:
--   Dev  (target.name = 'default'): all models → SF_DBT_TABLEAU (one schema)
--   Prod (target.name = 'prod'):    bronze → PROD_DB.BRONZE
--                                   silver → PROD_DB.SILVER
--                                   gold   → PROD_DB.GOLD
--
-- CRITICAL: target.name must match the Target Name field in your
--   dbt Cloud environment settings exactly (case-sensitive)
--
-- CRITICAL: NEVER put -- SQL comments inside {{ config() }} blocks
--   Use {# Jinja comments #} inside config() instead
--   SQL -- comments inside config() cause MacroSyntaxInvalid (dbt1502)
-- ══════════════════════════════════════════════════════════════════════

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {# target.schema = SF_DBT_TABLEAU in dev, GOLD in prod connection #}

    {%- if target.name == 'prod' -%}
        {# Production: use custom schema name exactly as written #}
        {# bronze → PROD_DB.BRONZE | silver → PROD_DB.SILVER | gold → PROD_DB.GOLD #}
        {{ custom_schema_name | trim }}

    {%- elif custom_schema_name is none -%}
        {# No custom schema configured on this model — use connection schema as-is #}
        {{ default_schema }}

    {%- else -%}
        {# Dev and CI: ignore custom schema, keep all models in one flat schema #}
        {# Makes local development navigation easy — one schema holds everything #}
        {{ default_schema }}

    {%- endif -%}

{%- endmacro %}

