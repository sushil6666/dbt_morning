{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_38', 'on_error', 'continue', 'fusion_limitation']
) }}

/*
  demo_38_on_error_continue_downstream
  ------------------------------------
<<<<<<< HEAD
  Downstream child kept in the DAG specifically to prove current Fusion behavior.

  WHAT THIS MODEL SHOWS IN THIS PROJECT:
    - there is a real parent/child dependency via the depends_on ref below
    - when the upstream model fails, Fusion still skips this child
    - that confirms on_error='continue' is not active yet in this environment

  WHY THE QUERY STILL READS dim_customers:
    If Fusion eventually supports continue, this child would be able to run
    independently because it does not require the failed upstream relation to
    exist in Snowflake.
=======
  Child model that should still run when its upstream fails under on_error='continue'.

  KNOWN LIMITATION — dbt-fusion (dbt1701):
    on_error='continue' is not yet supported in dbt Fusion. This model will be
    SKIPPED (not run) until Fusion implements the feature. On dbt Core 1.12+
    this model runs successfully even when the upstream fails.

  WHY THE depends_on COMMENT EXISTS:
    Establishes the real DAG edge so dbt tracks the parent/child relationship.
    The SQL reads from dim_customers (not the failed parent) so it can succeed
    even when the upstream table was never created.
>>>>>>> fe0ea4fae18a633e7a79fb93e7e87a1edacf9c9c
*/

-- depends_on: {{ ref('demo_38_on_error_continue_upstream') }}

select
    count(*) as customer_count,
    current_timestamp()::timestamp_ntz as demo_ran_at
from {{ ref('dim_customers') }}
