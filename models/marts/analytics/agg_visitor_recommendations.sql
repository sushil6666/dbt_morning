{{ config(materialized='table') }}

-- Are some visitor types more likely to recommend?
-- Grain: one row per visitor type
-- NPS segmentation: Promoter >= 70%, Passive >= 50%, Detractor < 50%

with feedback as (
    select * from {{ ref('stg_feedback__haunted_visitor_feedback') }}
),

aggregated as (
    select
        visitor_type,
        count(*)                                            as total_visits,
        round(
            sum(case when would_recommend then 1 else 0 end)::numeric
            / nullif(count(*), 0) * 100, 2
        )                                                   as recommendation_rate
    from feedback
    group by 1
)

select
    visitor_type,
    recommendation_rate,
    total_visits,
    case
        when recommendation_rate >= 70  then 'Promoter'
        when recommendation_rate >= 50  then 'Passive'
        else 'Detractor'
    end                                                     as nps_segment,
    rank() over (order by recommendation_rate desc)         as promoter_rank
from aggregated
