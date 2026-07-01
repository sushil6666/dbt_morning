{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('dim_customers') }}
),

visits as (
    select * from {{ ref('fct_visits') }}
),

customer_visit_rollup as (
    select
        customer_id,
        count(*) as total_visits,
        min(visit_date) as first_visit_date,
        max(visit_date) as most_recent_visit_date,
        sum(ticket_price) as lifetime_ticket_revenue,
        sum(in_park_spend) as lifetime_in_park_spend,
        sum(total_visit_spend) as lifetime_total_spend,
        avg(total_visit_spend) as avg_spend_per_visit,
        avg(avg_rating) as avg_visit_rating,
        sum(feedback_count) as feedback_submissions,
        sum(case when is_discounted then 1 else 0 end) as discounted_visit_count,
        sum(case when is_same_day_visit then 1 else 0 end) as same_day_visit_count,
        sum(case when is_advance_purchase then 1 else 0 end) as advance_purchase_visit_count,
        avg(booking_lead_days) as avg_booking_lead_days
    from visits
    group by 1
),

final as (
    select
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.registration_date,
        c.loyalty_tier,
        c.customer_value_segment,
        c.customer_lifecycle_stage,
        r.total_visits,
        r.first_visit_date,
        r.most_recent_visit_date,
        datediff('day', r.most_recent_visit_date, current_date()) as days_since_last_visit,
        r.lifetime_ticket_revenue,
        r.lifetime_in_park_spend,
        r.lifetime_total_spend,
        r.avg_spend_per_visit,
        r.avg_visit_rating,
        r.feedback_submissions,
        r.discounted_visit_count,
        r.same_day_visit_count,
        r.advance_purchase_visit_count,
        round(r.avg_booking_lead_days, 2) as avg_booking_lead_days,
        r.total_visits > 1 as is_repeat_visitor,
        case
            when r.lifetime_total_spend >= 250 then 'High Value'
            when r.lifetime_total_spend >= 100 then 'Mid Value'
            else 'Standard'
        end as behavioral_value_segment,
        case
            when datediff('day', r.most_recent_visit_date, current_date()) <= 90 then 'Active'
            when datediff('day', r.most_recent_visit_date, current_date()) <= 365 then 'Cooling'
            else 'Lapsed'
        end as recency_segment,
        case
            when datediff('day', r.most_recent_visit_date, current_date()) > 365 then 'High'
            when datediff('day', r.most_recent_visit_date, current_date()) > 90 then 'Medium'
            else 'Low'
        end as retention_risk_level
    from customers c
    inner join customer_visit_rollup r on c.customer_id = r.customer_id
)

select * from final
