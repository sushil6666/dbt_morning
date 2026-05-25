{{ config(materialized='table') }}

with tickets as (
    select * from {{ ref('stg_external_haunted__haunted_house_tickets') }}
),

houses as (
    select * from {{ ref('stg_external_haunted__haunted_houses') }}
)

select
    t.ticket_id,
    t.customer_id,
    t.haunted_house_id,
    h.haunted_house_name,
    h.capacity,
    h.fear_level,
    t.visit_date,
    t.ticket_price,
    t.created_at,
    t.updated_at
from tickets t
left join houses h on t.haunted_house_id = h.haunted_house_id
