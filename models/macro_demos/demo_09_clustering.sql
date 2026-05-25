{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_09'],
    post_hook="{{ apply_cluster_by(['visit_date', 'ticket_type']) }}"
) }}

SELECT
    ticket_id,
    customer_id,
    visit_date,
    ticket_type,
    total_visit_spend,
    avg_rating
FROM {{ ref('fct_visits') }}
