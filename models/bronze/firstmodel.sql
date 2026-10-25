{{
    config(
        materialized='view',
        secure=false,
        tags='unsecureview',
        query_tag='dbt_run',
        alias='unsecureview'
    )
}}
select '1' as dummy