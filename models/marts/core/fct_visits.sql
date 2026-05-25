{{ config(materialized='table') }}

with visits as (
    select * from {{ ref('int_customer_visits') }}
),

date_dim as (
    select * from {{ ref('dim_dates') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['v.ticket_id']) }} as visit_key,
    v.ticket_id,
    v.customer_id,
    v.visit_date,
    d.day_of_week,
    d.month_name,
    d.quarter,
    d.year,
    d.is_weekend,
    v.ticket_type,
    v.ticket_price,
    v.in_park_spend,
    v.total_visit_spend,
    v.avg_rating
from visits v
left join date_dim d on v.visit_date = d.date_day
