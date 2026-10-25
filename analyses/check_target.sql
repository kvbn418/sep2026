SELECT
    '{{ target.name }}'        AS target_name,
    '{{ target.database }}'    AS target_database,
    '{{ target.schema }}'      AS target_schema,
    '{{ target.warehouse }}'   AS target_warehouse,
    '{{ target.role }}'        AS target_role

    --dbt compile check_target