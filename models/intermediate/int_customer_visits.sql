{{ config(materialized='ephemeral') }}

with tickets as (
    select * from {{ ref('stg_sales__tickets') }}
),

sales as (
    select
        customer_id,
        visit_date,
        sum(total_amount) as in_park_spend
    from {{ ref('stg_sales_transactions__sales_transactions') }}
    group by 1, 2
),

feedback as (
    select
        customer_id,
        visit_date,
        avg(rating) as avg_rating,
        count(*) as feedback_count
    from {{ ref('stg_feedback__visitor_feedback') }}
    group by 1, 2
),

joined as (
    select
        t.ticket_id,
        t.customer_id,
        t.visit_date,
        t.ticket_type,
        t.purchase_date,
        t.purchase_channel,
        t.is_discounted,
        t.final_price as ticket_price,
        coalesce(s.in_park_spend, 0) as in_park_spend,
        t.final_price + coalesce(s.in_park_spend, 0) as total_visit_spend,
        datediff('day', t.purchase_date, t.visit_date) as booking_lead_days,
        datediff('day', t.purchase_date, t.visit_date) = 0 as is_same_day_visit,
        datediff('day', t.purchase_date, t.visit_date) >= 7 as is_advance_purchase,
        f.avg_rating,
        coalesce(f.feedback_count, 0) as feedback_count,
        coalesce(f.feedback_count, 0) > 0 as has_feedback
    from tickets t
    left join sales s
        on t.customer_id = s.customer_id
       and t.visit_date = s.visit_date
    left join feedback f
        on t.customer_id = f.customer_id
       and t.visit_date = f.visit_date
)

select * from joined
