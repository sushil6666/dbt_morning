{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_33', 'pre_hook', 'post_hook', 'audit'],
    pre_hook="{{ log_model_start() }}",
    post_hook="{{ log_model_end() }}"
) }}

/*
  demo_33_audit_hooks
  -------------------
  Demonstrates pre_hook + post_hook for structured audit logging.

  Execution order:
    1. pre_hook  → log_model_start()
                   Creates SF_TEST.AUDIT.DBT_RUN_LOG if needed.
                   Inserts a row: status='running', started_at=now.

    2. dbt builds this table (customer lifetime value summary below).

    3. post_hook → log_model_end()
                   Updates that row: status='success', rows_loaded=COUNT(*),
                   completed_at=now, elapsed_seconds=wall-clock duration.

  BUSINESS CONTEXT — why this model needs audit logs:
    Customer LTV (lifetime value) feeds the CRM, loyalty tier engine, and
    the VIP upgrade recommendation in upsell_opportunity. Finance, CRM, and
    ops all depend on it being fresh. The audit log answers:
      - "Is the LTV data from today's run or yesterday's?"
      - "How long did the build take? Is it within our 5-minute SLA?"
      - "Which dbt run_id produced what the BI tool is showing?"

  INSPECT THE AUDIT LOG:
    SELECT * FROM SF_TEST.AUDIT.DBT_RUN_LOG
    ORDER BY started_at DESC;

    -- Match a run to Snowflake query history:
    SELECT q.QUERY_TEXT, q.START_TIME, q.TOTAL_ELAPSED_TIME
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY q
    JOIN SF_TEST.AUDIT.DBT_RUN_LOG l
      ON PARSE_JSON(q.QUERY_TAG):run_id::string = l.run_id
    WHERE l.model_name = 'demo_33_audit_hooks'
    ORDER BY q.START_TIME DESC;
*/

with visits as (
    select * from {{ ref('fct_visits') }}
),

customers as (
    select
        customer_id,
        loyalty_tier,
        customer_value_segment,
        is_vip_member,
        registration_date
    from {{ ref('dim_customers') }}
),

ltv as (
    select
        v.customer_id,
        c.loyalty_tier,
        c.customer_value_segment,
        c.is_vip_member,
        c.registration_date,

        count(v.visit_date)                             as total_visits,
        min(v.visit_date)                               as first_visit_date,
        max(v.visit_date)                               as last_visit_date,
        datediff('day', min(v.visit_date),
                        max(v.visit_date))              as active_days,

        sum(v.total_visit_spend)                        as lifetime_spend,
        round(avg(v.total_visit_spend), 2)              as avg_spend_per_visit,
        round(avg(v.avg_rating), 2)                     as avg_satisfaction_rating,

        -- Spend velocity: avg spend per active month
        round(
            sum(v.total_visit_spend)
            / nullif(datediff('month',
                              min(v.visit_date),
                              max(v.visit_date)), 0),
        2)                                              as avg_monthly_spend

    from visits v
    inner join customers c on v.customer_id = c.customer_id
    group by 1, 2, 3, 4, 5
)

select
    customer_id,
    loyalty_tier,
    customer_value_segment,
    is_vip_member,
    registration_date,
    total_visits,
    first_visit_date,
    last_visit_date,
    active_days,
    lifetime_spend,
    avg_spend_per_visit,
    avg_satisfaction_rating,
    avg_monthly_spend,

    -- Segment by lifetime spend for marketing targeting
    case
        when lifetime_spend >= 500  then 'Platinum'
        when lifetime_spend >= 200  then 'Gold'
        when lifetime_spend >= 50   then 'Silver'
        else                             'Bronze'
    end                                                 as ltv_segment,

    current_timestamp()::timestamp_ntz                  as dbt_updated_at,
    '{{ invocation_id }}'                               as dbt_run_id

from ltv
