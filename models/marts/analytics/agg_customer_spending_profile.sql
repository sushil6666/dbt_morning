{{ config(materialized='table', enabled=false) }}

-- Customer spending profile by age group and gender.
-- DISABLED: upstream age/gender data from dim_customers is not yet joined
-- to visitor feedback. Enable and update the join logic when available.
-- Grain: one row per (age_group, gender)

with feedback as (
    select * from {{ ref('stg_feedback__haunted_visitor_feedback') }}
)

select
    customer_gender                                         as gender,
    case
        when customer_age < 18              then 'Under 18'
        when customer_age between 18 and 24 then '18-24'
        when customer_age between 25 and 34 then '25-34'
        when customer_age between 35 and 44 then '35-44'
        when customer_age between 45 and 54 then '45-54'
        else '55+'
    end                                                     as age_group,
    count(*)                                                as total_visits,
    round(avg(ticket_price), 2)                             as avg_ticket_price,
    round(sum(ticket_price), 2)                             as total_spend,
    round(avg(satisfaction_rating), 2)                      as avg_satisfaction
from feedback
group by 1, 2
