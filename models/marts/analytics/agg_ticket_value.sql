{{ config(materialized='table') }}

-- Which ticket type delivers the best value?
-- Grain: one row per (haunted_house, ticket_tier)
-- Value index = avg_satisfaction / avg_price * 100

with feedback as (
    select * from {{ ref('stg_feedback__haunted_visitor_feedback') }}
),

aggregated as (
    select
        haunted_house_name,
        case
            when includes_vip_benefits and includes_fast_pass  then 'VIP + Fast Pass'
            when includes_vip_benefits                          then 'VIP Only'
            when includes_fast_pass                             then 'Fast Pass Only'
            else 'Standard'
        end                                                 as ticket_tier,
        round(avg(satisfaction_rating), 2)                  as avg_satisfaction,
        round(avg(ticket_price), 2)                         as avg_price,
        count(*)                                            as visit_count
    from feedback
    group by 1, 2
)

select
    haunted_house_name,
    ticket_tier,
    avg_satisfaction,
    avg_price,
    visit_count,
    round(avg_satisfaction / nullif(avg_price, 0) * 100, 4) as value_index,
    rank() over (
        order by avg_satisfaction / nullif(avg_price, 0) desc
    )                                                       as value_rank
from aggregated
