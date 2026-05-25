{{ config(materialized='ephemeral') }}

-- Aggregates ticket and in-park revenue by visit date

with ticket_revenue as (
    select
        visit_date,
        sum(final_price)            as ticket_revenue,
        count(distinct customer_id) as unique_visitors,
        count(ticket_id)            as tickets_sold
    from {{ ref('stg_sales__tickets') }}
    group by 1
),

sales_revenue as (
    select
        visit_date,
        sum(total_amount)                                                   as in_park_revenue,
        sum(case when category = 'food'        then total_amount else 0 end) as food_revenue,
        sum(case when category = 'merchandise' then total_amount else 0 end) as merch_revenue
    from {{ ref('stg_sales_transactions__sales_transactions') }}
    group by 1
)

select
    coalesce(t.visit_date, s.visit_date)        as visit_date,
    coalesce(t.ticket_revenue, 0)               as ticket_revenue,
    coalesce(s.in_park_revenue, 0)              as in_park_revenue,
    coalesce(s.food_revenue, 0)                 as food_revenue,
    coalesce(s.merch_revenue, 0)                as merch_revenue,
    coalesce(t.ticket_revenue, 0)
        + coalesce(s.in_park_revenue, 0)        as total_revenue,
    coalesce(t.unique_visitors, 0)              as unique_visitors,
    coalesce(t.tickets_sold, 0)                 as tickets_sold
from ticket_revenue t
full outer join sales_revenue s on t.visit_date = s.visit_date
