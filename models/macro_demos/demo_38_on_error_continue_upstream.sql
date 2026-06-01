{{ config(
    materialized='table',
    on_error='continue',
    tags=['macro_demo', 'demo_38', 'on_error', 'continue']
) }}

/*
  demo_38_on_error_continue_upstream
  ----------------------------------
  Intentionally fails to demonstrate the new on_error: continue behavior.

  WHAT THIS MODEL SHOWS:
    - the model itself still errors
    - because on_error='continue', dbt does not automatically skip its children
    - downstream models can keep running if they do not rely on this relation existing

  EXPECTED BEHAVIOUR:
    - this model fails at execution time with a division-by-zero error
    - downstream demo_38_on_error_continue_downstream still runs

  Run:
    dbt build --select demo_38_on_error_continue_upstream+
*/

select
    customer_id,
    1 / 0 as force_failure
from {{ ref('dim_customers') }}
