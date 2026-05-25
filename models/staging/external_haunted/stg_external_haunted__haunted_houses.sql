{{ config(materialized='view') }}

-- Maps raw_rides (is_haunted = true) to the haunted house dimension schema.
-- ride_id → haunted_house_id
-- thrill_level → fear_level (numeric 1-5)

with source as (
    select * from {{ source('external_haunted', 'haunted_houses') }}
    where is_haunted = true
),

renamed as (
    select
        ride_id::int                                as haunted_house_id,
        ride_name                                   as haunted_house_name,
        capacity_per_hour::int                      as capacity,

        case thrill_level
            when 'extreme' then 5
            when 'high'    then 4
            when 'medium'  then 3
            when 'low'     then 2
            else 3
        end::int                                    as fear_level

    from source
)

select * from renamed
