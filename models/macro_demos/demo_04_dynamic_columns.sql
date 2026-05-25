{{ config(
    materialized='view',
    tags=['macro_demo', 'demo_04']
) }}

{#
  Demonstrates get_columns_except() — dynamically selects all columns from the source
  relation minus any internal/load columns. The macro calls adapter.get_columns_in_relation()
  at compile time so dbt resolves the column list from the live schema.
  NOTE: requires the upstream model to exist before this one compiles.
        On a fresh deploy, run stg_sales_transactions first:
        dbt run --select stg_sales_transactions__sales_transactions && dbt run --select demo_04_dynamic_columns
#}

{% set source_relation = ref('stg_sales_transactions__sales_transactions') %}

SELECT
    {{ get_columns_except(source_relation, exclude_cols=[]) }}
FROM {{ source_relation }}
