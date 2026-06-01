{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_38', 'on_error', 'continue', 'fusion_limitation']
) }}

/*
  demo_38_on_error_continue_downstream
  ------------------------------------
  Downstream child kept in the DAG specifically to prove current Fusion behavior.

  WHAT THIS MODEL SHOWS IN THIS PROJECT:
    - there is a real parent/child dependency via the depends_on ref below
    - when the upstream model fails, Fusion still skips this child
    - that confirms on_error='continue' is not active yet in this environment

  WHY THE QUERY STILL READS dim_customers:
    If Fusion eventually supports continue, this child would be able to run
    independently because it does not require the failed upstream relation to
    exist in Snowflake.
*/

-- depends_on: {{ ref('demo_38_on_error_continue_upstream') }}

select
    count(*) as customer_count,
    current_timestamp()::timestamp_ntz as demo_ran_at
from {{ ref('dim_customers') }}
