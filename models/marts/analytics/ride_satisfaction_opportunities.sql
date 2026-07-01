{{ config(materialized='table') }}

with rides as (
    select * from {{ ref('agg_ride_popularity') }}
),

final as (
    select
        ride_key,
        ride_id,
        ride_name,
        ride_type,
        thrill_level,
        zone,
        is_haunted,
        status,
        capacity_per_hour,
        avg_wait_minutes,
        total_reviews,
        avg_rating,
        positive_review_pct,
        review_count_band,
        rating_tier,
        popularity_segment,
        wait_experience_segment,
        case
            when total_reviews = 0 then 'Collect More Feedback'
            when avg_wait_minutes >= 25 and avg_rating < 3 then 'Improve Guest Experience'
            when avg_rating >= 4 and total_reviews >= 3 and avg_wait_minutes < 25 then 'Promote Ride'
            when avg_rating >= 4 and total_reviews < 3 then 'Build Awareness'
            else 'Monitor Performance'
        end as recommended_action,
        case
            when total_reviews = 0 then 'Medium'
            when avg_wait_minutes >= 25 and avg_rating < 3 then 'High'
            when avg_rating >= 4 and total_reviews < 3 then 'Medium'
            else 'Low'
        end as action_priority
    from rides
)

select * from final
