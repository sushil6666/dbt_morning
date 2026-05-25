{{ config(
    materialized='view',
    tags=['macro_demo', 'demo_14']
) }}

{#
  Reads only current (active) rows from the snp_customers snapshot using
  read_current_snapshot() — downstream models stay clean without repeating
  the dbt_valid_to IS NULL filter.
  Also surfaces SCD metadata columns via scd_metadata_columns().
#}

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    {{ scd_metadata_columns() }}
FROM {{ read_current_snapshot(ref('snp_customers')) }}
