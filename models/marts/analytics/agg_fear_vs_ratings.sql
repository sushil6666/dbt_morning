{{ config(materialized='table') }}

-- Is there a link between fear level and satisfaction ratings?
-- Grain: one row per (visitor_type, fear_level) + one overall row per fear_level

with feedback as (
    select * from {{ ref('stg_feedback__haunted_visitor_feedback') }}
),

by_type_and_fear as (
    select
        visitor_type,
        fear_level,
        round(avg(satisfaction_rating), 2)  as avg_satisfaction,
        count(*)                            as total_visits
    from feedback
    group by 1, 2
),

overall_by_fear as (
    select
        'All Visitors'                      as visitor_type,
        fear_level,
        round(avg(satisfaction_rating), 2)  as avg_satisfaction,
        count(*)                            as total_visits
    from feedback
    group by 2
)

select * from by_type_and_fear
union all
select * from overall_by_fear
