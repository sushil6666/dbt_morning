{{ config(materialized='table') }}

-- Customer lifetime value segmented by loyalty tier and value segment.
-- Joins dim_customers to fct_all_ticket_sales to compute actual spend metrics.

with customers as (
    select * from {{ ref('dim_customers') }}
),

ticket_sales as (
    select
        customer_id,
        count(*)            as total_visits,
        sum(ticket_price)   as lifetime_spend,
        avg(ticket_price)   as avg_spend_per_visit
    from {{ ref('fct_all_ticket_sales') }}
    group by customer_id
),

joined as (
    select
        c.customer_id,
        c.loyalty_tier,
        c.customer_value_segment,
        c.age_group,
        c.is_vip_member,
        coalesce(t.total_visits, 0)         as total_visits,
        coalesce(t.lifetime_spend, 0)       as lifetime_spend,
        coalesce(t.avg_spend_per_visit, 0)  as avg_spend_per_visit
    from customers c
    left join ticket_sales t on c.customer_id = t.customer_id
)

select
    loyalty_tier,
    customer_value_segment,
    count(customer_id)                                          as total_customers,
    round(avg(lifetime_spend), 2)                               as avg_lifetime_spend,
    round(avg(total_visits), 2)                                 as avg_visits,
    round(avg(avg_spend_per_visit), 2)                          as avg_spend_per_visit,
    sum(lifetime_spend)                                         as total_segment_revenue,
    round(
        sum(lifetime_spend) / nullif(count(customer_id), 0), 2
    )                                                           as clv
from joined
group by 1, 2
order by clv desc
