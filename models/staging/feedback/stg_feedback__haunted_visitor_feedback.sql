{{ config(materialized='view') }}

-- Maps raw_feedback to the haunted house visitor feedback schema.
-- Joins to raw_rides (via external_haunted.haunted_houses) to get the house name and fear level.
-- Columns not available in raw_feedback (ticket_price, visitor_type, etc.) are set to NULL.

with feedback as (
    select * from {{ source('feedback', 'visitor_feedback') }}
),

rides as (
    select
        ride_id,
        ride_name,
        thrill_level
    from {{ source('external_haunted', 'haunted_houses') }}
    where is_haunted = true
),

renamed as (
    select
        f.feedback_id,
        null::number                                            as sale_id,

        -- Haunted house name from joined ride; fallback if feedback has no ride_id
        coalesce(r.ride_name, 'Unknown House')                  as haunted_house_name,

        -- Map thrill_level to numeric fear_level
        case r.thrill_level
            when 'extreme' then 5
            when 'high'    then 4
            when 'medium'  then 3
            when 'low'     then 2
            else 3
        end::int                                                as fear_level,

        null::numeric(10, 2)                                    as ticket_price,
        null::boolean                                           as includes_vip_benefits,
        null::boolean                                           as includes_fast_pass,

        -- category (ride/food/general/etc.) used as proxy for visitor_type
        f.category                                              as visitor_type,

        null::int                                               as customer_age,
        null::varchar                                           as customer_gender,

        -- rating (1-5) mapped to satisfaction_rating
        f.rating::int                                           as satisfaction_rating,

        -- would_recommend = true when rating >= 4
        iff(f.rating >= 4, true, false)::boolean                as would_recommend,

        f.visit_date::date                                      as visit_date,
        null::int                                               as visit_hour

    from feedback f
    left join rides r on f.ride_id = r.ride_id
)

select * from renamed
