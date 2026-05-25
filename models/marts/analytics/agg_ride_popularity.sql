{{ config(materialized='table') }}

-- Ride popularity rankings based on review volume and average rating

with rides as (
    select * from {{ ref('dim_rides') }}
)

select
    ride_key,
    ride_id,
    ride_name,
    ride_type,
    thrill_level,
    zone,
    is_haunted,
    capacity_per_hour,
    avg_wait_minutes,
    total_reviews,
    avg_rating,
    positive_review_pct,
    case
        when avg_rating >= 4.5 then 'Top Rated'
        when avg_rating >= 3.5 then 'Well Rated'
        when avg_rating >= 2.5 then 'Average'
        when avg_rating >  0   then 'Below Average'
        else 'Not Yet Rated'
    end                                                         as rating_tier,
    rank() over (order by total_reviews desc)                   as review_volume_rank,
    rank() over (order by avg_rating desc nulls last)           as rating_rank
from rides
