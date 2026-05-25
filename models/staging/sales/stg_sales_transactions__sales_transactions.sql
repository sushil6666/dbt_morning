{{ config(materialized='view') }}

with source as (
    select * from {{ source('sales_transactions', 'sales_transactions') }}
),

renamed as (
    select
        transaction_id,
        customer_id,
        visit_date::date            as visit_date,
        category,
        item_name,
        quantity::int               as quantity,
        unit_price::numeric(10, 2)  as unit_price,
        total_amount::numeric(10, 2) as total_amount,
        payment_method,
        location
    from source
)

select * from renamed
