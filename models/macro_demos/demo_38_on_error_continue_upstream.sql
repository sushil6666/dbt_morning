{{ config(
    materialized='table',
    on_error='continue',
    tags=['macro_demo', 'demo_38', 'on_error', 'continue']
) }}

/*
  demo_38_on_error_continue_upstream
  ----------------------------------
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
