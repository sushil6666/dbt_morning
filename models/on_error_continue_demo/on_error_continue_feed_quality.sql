{{ config(
    materialized='table',
    schema='on_error_continue_demo',
    tags=['on_error_continue_demo', 'exception_handling']
) }}

/*
  Policy modes:
    safe  - calculate quality metrics without raising an exception
    warn  - emit a dbt warning and continue building
    error - raise a compiler error and stop this model
*/

{% set exception_mode = var('on_error_continue_demo_exception_mode', 'safe') %}
{% do apply_on_error_continue_feed_policy(exception_mode) %}

select
    count(*) as total_events,
    count_if(try_to_decimal(payment_amount_raw, 12, 2) is null) as malformed_amount_events,
    count_if(try_to_decimal(payment_amount_raw, 12, 2) < 0) as negative_amount_events,
    count_if(
        try_to_decimal(payment_amount_raw, 12, 2) is null
        or try_to_decimal(payment_amount_raw, 12, 2) < 0
    ) as events_requiring_review,
    round(
        events_requiring_review / nullif(total_events, 0),
        4
    ) as review_rate,
    '{{ exception_mode | lower }}' as policy_mode,
    current_timestamp()::timestamp_ntz as evaluated_at
from {{ ref('on_error_continue_payment_events') }}
