{{ config(materialized='table') }}

-- Which haunted house time slots are most profitable and best-rated?
-- Grain: one row per (haunted_house, visit_hour)

with feedback as (
    select * from {{ ref('stg_feedback__haunted_visitor_feedback') }}
)

select
    haunted_house_name,
    visit_hour,
    {{ visit_time_of_day('visit_hour') }}                   as time_slot,
    count(*)                                                as total_visits,
    round(sum(ticket_price), 2)                             as total_revenue,
    round(avg(ticket_price), 2)                             as avg_ticket_price,
    round(avg(satisfaction_rating), 2)                      as avg_satisfaction,
    round(
        sum(case when would_recommend then 1 else 0 end)::numeric
        / nullif(count(*), 0) * 100, 2
    )                                                       as recommendation_rate
from feedback
group by 1, 2, 3
