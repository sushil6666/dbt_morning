{{ config(
    enabled=true,
    materialized='table',
    on_error='continue',
    tags=['macro_demo', 'demo_38', 'on_error', 'continue']
) }}

/*
  Demonstrates `on_error='continue'` in dbt v2 Stable.

  The model is safe during normal builds. To force the upstream failure and
  prove that the independent downstream child still runs, use:

  dbt build --select demo_38_on_error_continue_upstream+ \
    --vars '{"demo_38_force_failure": true}'

  The command finishes with an expected error for this model, while
  demo_38_on_error_continue_downstream should still pass.
*/

{% set force_failure = var('demo_38_force_failure', false) %}

select
    customer_id,
    {% if force_failure %}
        1 / 0
    {% else %}
        1
    {% endif %} as force_failure
from {{ ref('dim_customers') }}
