-- snapshots/customers_snapshot.sql
-- Tracks changes to customer records over time (SCD Type 2)
-- Every time a customer's city, country, or email changes,
-- dbt creates a new row with the new values and expires the old row
-- dbt_valid_to = NULL always means the CURRENT active record

{% snapshot customers_snapshot %}

    {{
        config(
            target_schema='SNAPSHOTS',
            target_database='DEV_DB',
            unique_key='customer_id',
            strategy='timestamp',
            updated_at='cust_updated_at'
        )
    }}

    -- Source of truth for the snapshot
    -- We read from the bronze staging model, not raw directly
    -- This ensures consistent column names and data types
    SELECT
        customer_id,
        cust_first_name,
        cust_last_name,
        cust_full_name,
        cust_email,
        cust_country,
        cust_city,
        cust_updated_at

    FROM {{ ref('stg_customers') }}

{% endsnapshot %}