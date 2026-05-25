{{ config(materialized='table') }}

with ticket_types as (
    select * from {{ ref('stg_park_assets__ticket_types') }}
)

select
    ticket_id,
    ticket_type_name,
    description,
    price,
    launch_date,
    includes_fast_pass,
    includes_vip_benefits,
    fear_level,
    duration_minutes,
    house_category,
    created_at,
    updated_at
from ticket_types
