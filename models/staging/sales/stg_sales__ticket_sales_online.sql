{{ config(materialized='view') }}

-- Filters raw_tickets to online purchases only.
-- ticket_id becomes sale_id (PK of the sale).
-- discount_percent is derived from discount_amount / base_price.

with source as (
    select * from {{ source('sales', 'ticket_sales_online') }}
    where purchase_channel = 'online'
),

renamed as (
    select
        ticket_id                                               as sale_id,
        customer_id,
        ticket_id,
        purchase_date::date                                     as purchase_date,
        visit_date::date                                        as visit_date,
        null::timestamp                                         as purchase_timestamp,
        final_price::numeric(10, 2)                             as ticket_price,

        case
            when base_price > 0
            then round((discount_amount / base_price) * 100, 2)
            else 0
        end::numeric(5, 2)                                      as discount_percent,

        null::int                                               as visit_hour,
        'credit_card'::varchar                                  as payment_method,
        'online'                                                as purchase_channel,
        true::boolean                                           as is_online

    from source
)

select * from renamed
