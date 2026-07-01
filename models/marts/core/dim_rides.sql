{{ config(materialized='table') }}

with rides as (
    select * from {{ ref('int_ride_metrics') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['ride_id']) }} as ride_key,
    ride_id,
    ride_name,
    ride_type,
    min_height_cm,
    thrill_level,
    zone,
    is_haunted,
    status,
    opened_date,
    capacity_per_hour,
    avg_wait_minutes,
    total_reviews,
    round(avg_rating, 2) as avg_rating,
    positive_reviews,
    neutral_reviews,
    negative_reviews,
    positive_review_pct,
    has_reviews,
    review_count_band
from rides
