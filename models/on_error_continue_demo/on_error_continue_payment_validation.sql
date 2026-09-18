{{ config(
    materialized='table',
    schema='on_error_continue_demo',
    on_error='continue',
    tags=['on_error_continue_demo', 'on_error_continue']
) }}

/*
  Safe mode uses TRY_TO_DECIMAL so every event can be inspected.
  Strict mode uses TO_DECIMAL and intentionally fails on EVT-1003:

  --vars '{"on_error_continue_demo_strict_validation": true}'
*/

{% set strict_validation = var('on_error_continue_demo_strict_validation', false) %}

select
    event_id,
    customer_id,
    {% if strict_validation %}
        to_decimal(payment_amount_raw, 12, 2)
    {% else %}
        try_to_decimal(payment_amount_raw, 12, 2)
    {% endif %} as payment_amount,
    currency,
    payment_status,
    event_timestamp
from {{ ref('on_error_continue_payment_events') }}
