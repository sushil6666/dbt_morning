{{ config(
    enabled=false,
    materialized='table',
    tags=['macro_demo', 'demo_38', 'on_error', 'continue', 'fusion_limitation']
) }}

/*
  demo_38_on_error_continue_upstream
  ----------------------------------
  PURPOSE:
    Documents the current dbt Fusion limitation around `on_error='continue'`.

  CURRENT STATUS:
    Disabled in this project because it fails intentionally with division by
    zero and is no longer meant to run as part of normal development builds.

  WHAT THIS MODEL DEMONSTRATES:
    - if configured with `on_error='continue'`, Fusion emits a not-yet-supported warning
    - this model fails intentionally at execution time
    - downstream children are still skipped, matching effective `skip_children` behavior

  WHY THIS DEMO STAYS IN THE REPO:
    It gives the project a concrete, reproducible example of the gap between
    supported dbt config syntax and current Fusion runtime behavior.

  EXPECTED RESULT IN THIS ENVIRONMENT IF RE-ENABLED WITH on_error='continue':
    - parse emits a not-yet-supported warning
    - this model fails with division by zero
    - `demo_38_on_error_continue_downstream` is skipped

  RUN:
    dbt build --select demo_38_on_error_continue_upstream+
*/

select
    customer_id,
    1 / 0 as force_failure
from {{ ref('dim_customers') }}
