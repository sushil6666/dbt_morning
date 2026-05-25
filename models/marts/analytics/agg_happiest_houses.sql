{{ config(materialized='table') }}

-- Which haunted houses have the happiest visitors?
-- Grain: one row per haunted house

with feedback as (
    select * from {{ ref('stg_feedback__haunted_visitor_feedback') }}
    where satisfaction_rating >= {{ var('min_satisfaction_rating', 3) }}
)

select
    haunted_house_name,
    count(*)                                                as total_visits,
    round(avg(satisfaction_rating), 2)                      as avg_satisfaction,
    round(
        sum(case when would_recommend then 1 else 0 end)::numeric
        / nullif(count(*), 0) * 100, 2
    )                                                       as recommendation_rate,
    rank() over (
        order by avg(satisfaction_rating) desc, count(*) desc
    )                                                       as happiness_rank
from feedback
group by 1
