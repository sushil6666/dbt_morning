{{ config(materialized='table') }}

with sales as (
    select * from {{ ref('stg_sales_transactions__sales_transactions') }}
),

date_dim as (
    select * from {{ ref('dim_dates') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['s.transaction_id']) }} as sales_key,
    s.transaction_id,
    s.customer_id,
    s.visit_date,
    d.day_of_week,
    d.month_name,
    d.quarter,
    d.year,
    d.is_weekend,
    s.category,
    s.item_name,
    s.quantity,
    s.unit_price,
    s.total_amount,
    s.payment_method,
    s.location
from sales s
left join date_dim d on s.visit_date = d.date_day
