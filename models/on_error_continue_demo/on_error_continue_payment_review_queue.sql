{{ config(
    materialized='table',
    schema='on_error_continue_demo',
    tags=['on_error_continue_demo', 'review_queue']
) }}

/*
  Independent evidence queue built directly from the raw payment feed.
  It remains current even when strict payment validation fails.
*/

with payment_events as (
    select
        event_id,
        customer_id,
        payment_amount_raw,
        try_to_decimal(payment_amount_raw, 12, 2) as payment_amount,
        currency,
        payment_status,
        event_timestamp
    from {{ ref('on_error_continue_payment_events') }}
),

review_events as (
    select
        *,
        case
            when payment_amount is null then 'malformed_amount'
            when payment_amount < 0 then 'negative_amount'
        end as review_reason
    from payment_events
    where payment_amount is null or payment_amount < 0
)

select * from review_events
