{{ config(materialized='view') }}

-- Derives a ticket type dimension from distinct ticket_type values in raw_tickets.
-- Each unique ticket_type (day_pass, weekend_pass, annual_pass, group_pass) becomes one row.
-- price is the average base_price for that ticket type.

with ticket_base as (
    select
        ticket_type,
        avg(base_price) as avg_price
    from {{ source('park_assets', 'ticket_types') }}
    group by ticket_type
)

select
    row_number() over (order by ticket_type)            as ticket_id,
    ticket_type                                         as ticket_type_name,
    null::varchar                                       as description,
    avg_price::numeric(10, 2)                           as price,
    null::date                                          as launch_date,

    iff(ticket_type in ('weekend_pass', 'annual_pass'),
        true, false)::boolean                           as includes_fast_pass,

    iff(ticket_type = 'annual_pass',
        true, false)::boolean                           as includes_vip_benefits,

    case ticket_type
        when 'annual_pass'  then 5
        when 'weekend_pass' then 4
        when 'day_pass'     then 3
        else 2
    end::int                                            as fear_level,

    case ticket_type
        when 'annual_pass'  then 240
        when 'weekend_pass' then 180
        else 120
    end::int                                            as duration_minutes,

    null::varchar                                       as house_category,
    current_timestamp                                   as created_at,
    current_timestamp                                   as updated_at

from ticket_base
