{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_38', 'on_error', 'continue']
) }}

/*
  demo_38_on_error_continue_downstream
  ------------------------------------
  Child model that should still run when its upstream fails under on_error='continue'.

  KNOWN LIMITATION — dbt-fusion (dbt1701):
    on_error='continue' is not yet supported in dbt Fusion. This model will be
    SKIPPED (not run) until Fusion implements the feature. On dbt Core 1.12+
    this model runs successfully even when the upstream fails.

  WHY THE depends_on COMMENT EXISTS:
    Establishes the real DAG edge so dbt tracks the parent/child relationship.
    The SQL reads from dim_customers (not the failed parent) so it can succeed
    even when the upstream table was never created.
*/

-- depends_on: {{ ref('demo_38_on_error_continue_upstream') }}

select
    count(*) as customer_count,
    current_timestamp()::timestamp_ntz as demo_ran_at
from {{ ref('dim_customers') }}
