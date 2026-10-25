{% snapshot orders_snapshot %}

    {{
        config(
            target_schema='SNAPSHOTS',
            target_database='DEV_DB',
            unique_key='order_id',
            strategy='check',
            check_cols=['ord_status', 'ord_shipping_country']
        )
    }}

    SELECT
        order_id,
        customer_id,
        order_date,
        ord_status,
        ord_shipping_country,
        ord_total_amount_usd

    FROM {{ ref('stg_orders') }}

{% endsnapshot %}