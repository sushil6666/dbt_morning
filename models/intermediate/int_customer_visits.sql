{{ config(materialized='ephemeral') }}

-- Combines ticket purchases with in-park spend and feedback per visit

with tickets as (
    select * from {{ ref('stg_sales__tickets') }}
),

sales as (
    select
        customer_id,
        visit_date,
        sum(total_amount) as total_in_park_spend
    from {{ ref('stg_sales_transactions__sales_transactions') }}
    group by 1, 2
),

feedback as (
    select
        customer_id,
        visit_date,
        avg(rating) as avg_rating
    from {{ ref('stg_feedback__visitor_feedback') }}
    group by 1, 2
),

joined as (
    select
        t.ticket_id,
        t.customer_id,
        t.visit_date,
        t.ticket_type,
        t.final_price                                               as ticket_price,
        coalesce(s.total_in_park_spend, 0)                         as in_park_spend,
        t.final_price + coalesce(s.total_in_park_spend, 0)         as total_visit_spend,
        f.avg_rating
    from tickets t
    left join sales    s on t.customer_id = s.customer_id and t.visit_date = s.visit_date
    left join feedback f on t.customer_id = f.customer_id and t.visit_date = f.visit_date
)

select * from joined
