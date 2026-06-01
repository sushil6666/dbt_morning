{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_38', 'on_error', 'continue']
) }}

/*
  demo_38_on_error_continue_downstream
  ------------------------------------
  Downstream child that still runs even when its upstream fails, because the
  dependency is DAG-only and the SQL itself reads from an independent relation.

  WHY THE depends_on COMMENT EXISTS:
    We want a real parent/child relationship so dbt can demonstrate that this
    child is not skipped when the parent fails under on_error='continue'.
    The query itself does not read the failed relation, otherwise Snowflake would
    fail because the upstream table was never created.
*/

-- depends_on: {{ ref('demo_38_on_error_continue_upstream') }}

select
    count(*) as customer_count,
    current_timestamp()::timestamp_ntz as demo_ran_at
from {{ ref('dim_customers') }}
