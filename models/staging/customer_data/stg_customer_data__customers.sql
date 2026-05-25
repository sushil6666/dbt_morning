{{ config(materialized='view') }}

-- Maps RAW.raw_customers to the haunted house customer schema.
-- Missing columns (gender, address, zip_code, etc.) are derived or set to NULL.

with source as (
    select * from {{ source('customer_data', 'customers') }}
),

renamed as (
    select
        customer_id,
        first_name,
        last_name,
        lower(email)                                            as email,
        phone,
        null::varchar                                           as address,
        null::varchar                                           as city,
        null::varchar                                           as state,
        null::varchar                                           as zip_code,
        datediff('year', date_of_birth, current_date())::int    as age,
        null::varchar                                           as gender,

        -- Derive VIP status from membership_type
        iff(membership_type in ('gold', 'platinum'),
            true, false)::boolean                               as is_vip_member,

        -- marketing_opt_in not in source — default false
        false::boolean                                          as marketing_opt_in,

        -- Derive preferred scare level from membership tier
        case membership_type
            when 'platinum' then 3
            when 'gold'     then 2
            else 1
        end::int                                                as preferred_scare_level,

        -- Derive loyalty points from membership tier
        case membership_type
            when 'platinum' then 1000
            when 'gold'     then 500
            when 'silver'   then 250
            else 100
        end::int                                                as loyalty_points,

        created_at::date                                        as registration_date,
        created_at::timestamp                                   as created_at,
        created_at::timestamp                                   as updated_at

    from source
)

select * from renamed
