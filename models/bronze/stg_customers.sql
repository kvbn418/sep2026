-- ══════════════════════════════════════════════════════════════════════
-- stg_customers.sql
-- Bronze staging model for customers
-- Materialization: VIEW (no storage cost, always reads live RAW_DB data)
-- Grain: one row per customer_id
-- Source: RAW_DB.ECOMMERCE_RAW.CUSTOMERS
-- Output: DEV_DB.SF_DBT_TABLEAU.STG_CUSTOMERS (dev)
--         PROD_DB.BRONZE.STG_CUSTOMERS (prod)
--
-- What this model does:
--   1. Renames columns with src_ prefix to avoid SQL keyword conflicts
--   2. Applies business naming: cust_ prefix for all output columns
--   3. Trims whitespace from string columns
--   4. Lowercases email for consistency
--   5. Concatenates first + last name into full_name
--   6. Casts created_at to DATE, updated_at to TIMESTAMP_NTZ
-- ══════════════════════════════════════════════════════════════════════

{{ config(materialized='view', schema='bronze') }}

WITH source AS (
    -- Rename columns with src_ prefix to avoid SQL keyword conflicts
    -- e.g. first_name and last_name are SQL keywords in some dialects
    SELECT
        customer_id,
        first_name       AS src_first_name,
        last_name        AS src_last_name,
        email            AS src_email,
        phone            AS src_phone,
        country          AS src_country,
        city             AS src_city,
        created_at       AS src_created_at,
        updated_at       AS src_updated_at,
        _fivetran_synced AS src_fivetran_synced
    FROM {{ source('ecommerce', 'customers') }}
    -- source() declares lineage to RAW_DB and enables freshness checks
    -- Never hardcode: FROM RAW_DB.ECOMMERCE_RAW.CUSTOMERS
),

final AS (
    SELECT
        -- Primary key: unchanged from source
        customer_id,

        -- Name columns: trim whitespace from raw values
        TRIM(src_first_name)                                AS cust_first_name,
        TRIM(src_last_name)                                 AS cust_last_name,

        -- Derived: concatenate full name for display in BI tools
        TRIM(src_first_name) || ' ' || TRIM(src_last_name) AS cust_full_name,

        -- Contact: lowercase email for consistent joins and deduplication
        LOWER(TRIM(src_email))                              AS cust_email,
        src_phone                                           AS cust_phone,

        -- Location: trim raw values
        TRIM(src_country)                                   AS cust_country,
        TRIM(src_city)                                      AS cust_city,

        -- Dates: cast to correct Snowflake types
        -- DATE is sufficient for created date — no time component needed
        src_created_at::DATE                                AS cust_created_date,
        -- TIMESTAMP_NTZ for updated_at — used in incremental model filters
        src_updated_at::TIMESTAMP_NTZ                       AS cust_updated_at,

        -- Audit: when Fivetran last loaded this row
        src_fivetran_synced                                 AS cust_source_loaded_at

    FROM source
)

-- Final SELECT: explicit column list for clarity and lineage tracking
SELECT
    customer_id,
    cust_first_name,
    cust_last_name,
    cust_full_name,
    cust_email,
    cust_phone,
    cust_country,
    cust_city,
    cust_created_date,
    cust_updated_at,
    cust_source_loaded_at
FROM final