{{ config(materialized='ephemeral') }}

-- Enriches ride catalog with aggregated feedback metrics

with rides as (
    select * from {{ ref('stg_park_assets__rides') }}
),

feedback_agg as (
    select
        ride_id,
        count(feedback_id)                                              as total_reviews,
        avg(rating)                                                     as avg_rating,
        sum(case when sentiment = 'positive' then 1 else 0 end)        as positive_reviews,
        sum(case when sentiment = 'negative' then 1 else 0 end)        as negative_reviews
    from {{ ref('stg_feedback__visitor_feedback') }}
    where ride_id is not null
    group by 1
)

select
    r.ride_id,
    r.ride_name,
    r.ride_type,
    r.thrill_level,
    r.zone,
    r.is_haunted,
    r.capacity_per_hour,
    r.avg_wait_minutes,
    coalesce(f.total_reviews, 0)    as total_reviews,
    coalesce(f.avg_rating, 0)       as avg_rating,
    coalesce(f.positive_reviews, 0) as positive_reviews,
    coalesce(f.negative_reviews, 0) as negative_reviews,
    case
        when coalesce(f.total_reviews, 0) > 0
            then round(f.positive_reviews::numeric / f.total_reviews * 100, 2)
        else 0
    end                             as positive_review_pct
from rides r
left join feedback_agg f on r.ride_id = f.ride_id
