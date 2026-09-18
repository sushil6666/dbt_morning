{{ config(
    materialized='table',
    schema='on_error_continue_demo',
    tags=['on_error_continue_demo', 'on_error_continue', 'incident_audit']
) }}

/*
  This child has a real DAG dependency on the validator, but reads the raw seed
  independently. With on_error='continue' on the parent, this audit still runs
  after strict validation fails and tells the operator what arrived.
*/

-- depends_on: {{ ref('on_error_continue_payment_validation') }}

select
    count(*) as total_events,
    count_if(try_to_decimal(payment_amount_raw, 12, 2) is null) as malformed_amount_events,
    count_if(try_to_decimal(payment_amount_raw, 12, 2) < 0) as negative_amount_events,
    count_if(payment_status = 'declined') as declined_events,
    current_timestamp()::timestamp_ntz as audited_at
from {{ ref('on_error_continue_payment_events') }}
