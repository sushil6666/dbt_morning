{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('dim_customers') }}
),

visits as (
    select * from {{ ref('fct_visits') }}
),

customer_visit_metrics as (
    select
        customer_id,
        count(*) as total_visits,
        sum(ticket_price) as lifetime_ticket_revenue,
        sum(in_park_spend) as lifetime_in_park_spend,
        sum(total_visit_spend) as lifetime_total_spend,
        avg(total_visit_spend) as avg_spend_per_visit
    from visits
    group by 1
),

joined as (
    select
        c.customer_id,
        c.loyalty_tier,
        c.customer_value_segment,
        coalesce(v.total_visits, 0) as total_visits,
        coalesce(v.lifetime_ticket_revenue, 0) as lifetime_ticket_revenue,
        coalesce(v.lifetime_in_park_spend, 0) as lifetime_in_park_spend,
        coalesce(v.lifetime_total_spend, 0) as lifetime_total_spend,
        coalesce(v.avg_spend_per_visit, 0) as avg_spend_per_visit
    from customers c
    left join customer_visit_metrics v on c.customer_id = v.customer_id
)

select
    loyalty_tier,
    customer_value_segment,
    count(customer_id) as total_customers,
    round(avg(lifetime_ticket_revenue), 2) as avg_lifetime_ticket_revenue,
    round(avg(lifetime_in_park_spend), 2) as avg_lifetime_in_park_spend,
    round(avg(lifetime_total_spend), 2) as avg_lifetime_total_spend,
    round(avg(total_visits), 2) as avg_visits,
    round(avg(avg_spend_per_visit), 2) as avg_spend_per_visit,
    round(sum(lifetime_total_spend), 2) as total_segment_revenue,
    round(sum(lifetime_total_spend) / nullif(count(customer_id), 0), 2) as clv
from joined
group by 1, 2
order by clv desc
