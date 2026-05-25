{{ config(materialized='table') }}

-- How does ticket spending vary relative to Halloween?
-- Grain: one row per date bucket (proximity to Oct 31)
-- Var: halloween_analysis_start_date controls how far back to include data

with sales as (
    select * from {{ ref('fct_all_ticket_sales') }}
    where visit_date >= '{{ var("halloween_analysis_start_date", "2023-01-01") }}'
),

dates as (
    select * from {{ ref('dim_dates') }}
),

aggregated as (
    select
        case
            when d.days_to_halloween = 0                        then 'Halloween Day'
            when d.days_to_halloween between 1 and 7            then 'Week of Halloween'
            when d.days_to_halloween between 8 and 30           then 'October Pre-Halloween'
            when d.days_to_halloween between 31 and 60          then '2 Months Before'
            when d.days_to_halloween < 0
                and d.days_to_halloween >= -14                  then 'Post Halloween (2 wks)'
            when d.days_to_halloween < -14                      then 'Off Season'
            else 'Far Out'
        end                                                     as date_bucket,
        count(s.sale_id)                                        as total_tickets,
        round(sum(s.ticket_price), 2)                           as total_revenue,
        round(avg(s.ticket_price), 2)                           as avg_ticket_price,
        round(avg(s.discount_percent), 2)                       as avg_discount_pct
    from sales s
    join dates d on s.visit_date = d.date_day
    group by 1
)

select
    date_bucket,
    total_tickets,
    total_revenue,
    avg_ticket_price,
    avg_discount_pct,
    {{ spending_tier('avg_ticket_price') }}                     as spend_tier
from aggregated
