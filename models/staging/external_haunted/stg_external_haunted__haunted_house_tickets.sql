{{ config(materialized='view') }}

-- Maps raw_tickets to the haunted house ticket schema.
-- Since raw_tickets has no haunted_house_id, we assign one deterministically
-- using MOD(ticket_id - 1, number_of_haunted_houses) + 1.
-- This distributes tickets evenly across haunted houses for analytical purposes.

with tickets as (
    select * from {{ source('external_haunted', 'haunted_house_tickets') }}
),

haunted_houses as (
    select
        ride_id                                     as haunted_house_id,
        row_number() over (order by ride_id)        as house_rank
    from {{ source('external_haunted', 'haunted_houses') }}
    where is_haunted = true
),

house_count as (
    select count(*) as cnt from haunted_houses
),

renamed as (
    select
        t.ticket_id,
        t.customer_id,
        h.haunted_house_id,
        t.visit_date::date                          as visit_date,
        t.final_price::numeric(10, 2)               as ticket_price,
        t.purchase_date::timestamp                  as created_at,
        t.purchase_date::timestamp                  as updated_at

    from tickets t
    cross join house_count hc
    join haunted_houses h
        on h.house_rank = (mod(t.ticket_id - 1, hc.cnt) + 1)
)

select * from renamed
