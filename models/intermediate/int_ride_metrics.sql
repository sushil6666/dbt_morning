{{ config(materialized='ephemeral') }}

with rides as (
    select * from {{ ref('stg_park_assets__rides') }}
),

feedback_agg as (
    select
        ride_id,
        count(feedback_id) as total_reviews,
        avg(rating) as avg_rating,
        sum(case when rating >= 4 then 1 else 0 end) as positive_reviews,
        sum(case when rating = 3 then 1 else 0 end) as neutral_reviews,
        sum(case when rating <= 2 then 1 else 0 end) as negative_reviews
    from {{ ref('stg_feedback__visitor_feedback') }}
    where ride_id is not null
      and category = 'ride'
    group by 1
)

select
    r.ride_id,
    r.ride_name,
    r.ride_type,
    r.min_height_cm,
    r.thrill_level,
    r.zone,
    r.is_haunted,
    r.status,
    r.opened_date,
    r.capacity_per_hour,
    r.avg_wait_minutes,
    coalesce(f.total_reviews, 0) as total_reviews,
    coalesce(f.avg_rating, 0) as avg_rating,
    coalesce(f.positive_reviews, 0) as positive_reviews,
    coalesce(f.neutral_reviews, 0) as neutral_reviews,
    coalesce(f.negative_reviews, 0) as negative_reviews,
    case
        when coalesce(f.total_reviews, 0) > 0
            then round(f.positive_reviews::numeric / f.total_reviews * 100, 2)
        else 0
    end as positive_review_pct,
    coalesce(f.total_reviews, 0) > 0 as has_reviews,
    case
        when coalesce(f.total_reviews, 0) = 0 then 'No Reviews'
        when coalesce(f.total_reviews, 0) = 1 then 'Single Review'
        when coalesce(f.total_reviews, 0) between 2 and 4 then 'Low Volume'
        else 'Established'
    end as review_count_band
from rides r
left join feedback_agg f on r.ride_id = f.ride_id
