{{ config(
    materialized='table',
    pre_hook="ALTER SESSION SET TIMEZONE = 'UTC'",
    post_hook="GRANT SELECT ON {{ this }} TO ROLE {{ var('bi_role') }}"
) }}

with online_sales as (
    select * from {{ ref('stg_sales__ticket_sales_online') }}
),

physical_sales as (
    select * from {{ ref('stg_sales__ticket_sales_physical') }}
),

all_sales as (
    select * from online_sales
    union all
    select * from physical_sales
),

enriched as (
    select
        sale_id,
        customer_id,
        ticket_id,
        purchase_date,
        visit_date,
        purchase_timestamp,
        ticket_price,
        discount_percent,

        -- Derived discount bucket
        case
            when discount_percent = 0           then 'No Discount'
            when discount_percent < 10          then 'Low Discount'
            when discount_percent < 25          then 'Mid Discount'
            else 'High Discount'
        end                                     as discount_category,

        visit_hour,
        payment_method,
        purchase_channel,
        is_online,

        -- Derived visit flags
        (purchase_date = visit_date)            as same_day_visit,
        (datediff('day', purchase_date, visit_date) > 0) as advance_purchase,

        {{ visit_time_of_day('visit_hour') }}   as visit_time_category,

        case
            when month(visit_date) in (10, 11)  then 'Halloween Season'
            when month(visit_date) in (6, 7, 8) then 'Summer'
            when month(visit_date) in (12, 1, 2) then 'Winter'
            when month(visit_date) in (3, 4, 5)  then 'Spring'
            else 'Fall'
        end                                     as business_season,

        current_timestamp                       as created_at,
        current_timestamp                       as updated_at

    from all_sales
)

select * from enriched
