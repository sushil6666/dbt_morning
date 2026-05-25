{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_01']
) }}

SELECT
    ticket_id,
    customer_id,
    visit_date,
    ticket_type,
    total_visit_spend,
    avg_rating,
    {{ audit_columns() }}
FROM {{ ref('fct_visits') }}
