{{ config(materialized='view') }}

with source as (
    select * from {{ source('feedback', 'visitor_feedback') }}
),

renamed as (
    select
        feedback_id,
        customer_id,
        visit_date::date        as visit_date,
        ride_id,
        rating::int             as rating,
        category,
        sentiment,
        comments,
        submitted_at::timestamp as submitted_at,
        case
            when rating::int >= 4 then 'positive'
            when rating::int = 3  then 'neutral'
            else 'negative'
        end                     as rating_category
    from source
)

select * from renamed
