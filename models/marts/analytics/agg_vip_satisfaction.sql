{{ config(materialized='table') }}

-- Are VIP visitors actually more satisfied?
-- Grain: one row per (haunted_house, is_vip)

with feedback as (
    select * from {{ ref('stg_feedback__haunted_visitor_feedback') }}
),

house_vip_stats as (
    select
        haunted_house_name,
        includes_vip_benefits                               as is_vip,
        round(avg(satisfaction_rating), 2)                  as avg_satisfaction,
        count(*)                                            as visit_count
    from feedback
    group by 1, 2
),

vip_baseline as (
    select
        haunted_house_name,
        max(case when is_vip     then avg_satisfaction end) as vip_avg,
        max(case when not is_vip then avg_satisfaction end) as non_vip_avg
    from house_vip_stats
    group by 1
)

select
    h.haunted_house_name,
    h.is_vip,
    h.avg_satisfaction,
    round(b.vip_avg - b.non_vip_avg, 2)                    as satisfaction_gap
from house_vip_stats h
join vip_baseline b on h.haunted_house_name = b.haunted_house_name
