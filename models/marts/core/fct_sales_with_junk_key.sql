{{ config(materialized='table') }}

-- Fact table variant that replaces individual flag columns with a single
-- foreign key to dim_transaction_flags (junk dimension pattern).

with sales as (
    select * from {{ ref('fct_all_ticket_sales') }}
),

flags as (
    select * from {{ ref('dim_transaction_flags') }}
)

select
    s.sale_id,
    s.customer_id,
    s.ticket_id,
    s.purchase_date,
    s.visit_date,
    f.transaction_flag_key,
    s.ticket_price,
    s.discount_percent,
    s.visit_hour,
    s.payment_method,
    s.created_at,
    s.updated_at

from sales s
left join flags f
    on  s.purchase_channel    = f.purchase_channel
    and s.is_online           = f.is_online
    and s.discount_category   = f.discount_category
    and s.same_day_visit      = f.same_day_visit
    and s.advance_purchase    = f.advance_purchase
    and s.visit_time_category = f.visit_time_category
    and s.business_season     = f.business_season
