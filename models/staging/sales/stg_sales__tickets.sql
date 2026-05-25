{{ config(materialized='view') }}

with online as (
    select * from {{ source('sales', 'ticket_sales_online') }}
    where purchase_channel = 'online'
),

physical as (
    select * from {{ source('sales', 'ticket_sales_physical') }}
    where purchase_channel != 'online'
),

source as (
    select * from online
    union all
    select * from physical
),

renamed as (
    select
        ticket_id,
        customer_id,
        ticket_type,
        purchase_date::date             as purchase_date,
        visit_date::date                as visit_date,
        purchase_channel,
        {{ cast_price('base_price') }}                  as base_price,
        {{ cast_price('discount_amount', 12, 4) }}      as discount_amount,
        {{ cast_price('final_price') }}                 as final_price,
        nullif(promo_code, '')          as promo_code,
        case
            when discount_amount > 0 then true
            else false
        end                             as is_discounted
    from source
)

select * from renamed
