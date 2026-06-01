{{ config(
    materialized='table',
    on_error='continue',
    tags=['macro_demo', 'demo_38', 'on_error', 'continue', 'fusion_limitation']
) }}

/*
  demo_38_on_error_continue_upstream
  ----------------------------------
<<<<<<< HEAD
  Documents a current dbt Fusion limitation around on_error='continue'.

  WHAT THIS MODEL SHOWS IN THIS PROJECT:
    - the config parses, so the syntax is valid
    - dbt Fusion warns that on_error='continue' is not yet supported
    - the model itself errors at execution time
    - downstream children are still skipped, matching default skip_children behavior

  WHY KEEP THIS DEMO:
    This is a useful repo-level example of the gap between documented dbt config
    syntax and current Fusion runtime support. It prevents people from assuming
    they can rely on continue semantics in this environment.

  EXPECTED BEHAVIOUR IN THIS FUSION ENVIRONMENT:
    - parse emits a not-yet-supported warning
    - this model fails with division by zero
    - downstream demo_38_on_error_continue_downstream is skipped
=======
  Demonstrates the on_error: continue model config (dbt Core 1.12 beta).

  KNOWN LIMITATION — dbt-fusion (dbt1701):
    on_error='continue' is not yet supported in dbt Fusion. Fusion currently
    falls back to the default skip_children behaviour, so the downstream model
    will be skipped when this model fails. The config is intentionally kept in
    place and will activate automatically once Fusion implements dbt1701.

  WHAT THIS MODEL SHOWS (when on_error is fully supported):
    - this model errors at runtime (intentional division-by-zero)
    - because on_error='continue', dbt does NOT skip its children
    - downstream demo_38_on_error_continue_downstream still runs
>>>>>>> fe0ea4fae18a633e7a79fb93e7e87a1edacf9c9c

  CURRENT BEHAVIOUR on dbt-fusion:
    - this model errors
    - downstream model is SKIPPED (skip_children fallback)

  Run:
    dbt build --select demo_38_on_error_continue_upstream+
*/

select
    customer_id,
    1 / 0 as force_failure
from {{ ref('dim_customers') }}
