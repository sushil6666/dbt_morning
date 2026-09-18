{{ config(
    enabled=true,
    materialized='table',
    tags=['macro_demo', 'demo_38', 'on_error', 'continue']
) }}

/*
  Independent child used to demonstrate `on_error='continue'`.

  The explicit dependency creates the upstream -> downstream DAG edge, while
  this query reads dim_customers directly. That makes it safe for dbt to run
  this model after the demo upstream model fails.
*/

-- depends_on: {{ ref('demo_38_on_error_continue_upstream') }}

select
    count(*) as customer_count,
    current_timestamp()::timestamp_ntz as demo_ran_at
from {{ ref('dim_customers') }}
