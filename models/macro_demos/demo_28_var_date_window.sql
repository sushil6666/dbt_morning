{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_28', 'variables']
) }}

/*
  demo_28_var_date_window
  -----------------------
  Real-world pattern: configurable rolling lookback window via dbt variable.

  Production default (dbt_project.yml): lookback_days = 90
  The window controls how far back the visit frequency summary reaches.
  Finance and ops teams override it per run type without touching SQL:

    Standard dashboard (90 days):
      dbt run --select demo_28_var_date_window

    Month-end sprint (30 days):
      dbt run --vars '{"lookback_days": 30}' --select demo_28_var_date_window

    Annual churn review (365 days):
      dbt run --vars '{"lookback_days": 365}' --select demo_28_var_date_window

  WHY VAR NOT HARDCODE:
    Hardcoding the date means a code change — and a review cycle — every time
    the reporting window changes. A var externalises the business decision so
    analysts can self-serve without touching model SQL.

  EMITTED COLUMN:
    window_days is stamped onto every row so downstream consumers know which
    window produced the data without having to inspect run logs.
*/

{% set lookback_days = var('lookback_days', 90) %}

with recent_visits as (
    select
        customer_id,
        visit_date,
        ticket_type,
        total_visit_spend,
        avg_rating
    from {{ ref('fct_visits') }}
    where visit_date >= dateadd('day', -{{ lookback_days }}, current_date())
),

customer_summary as (
    select
        customer_id,
        count(*)                            as visit_count,
        sum(total_visit_spend)              as total_spend,
        round(avg(total_visit_spend), 2)    as avg_spend_per_visit,
        round(avg(avg_rating), 2)           as avg_rating,
        min(visit_date)                     as first_visit_in_window,
        max(visit_date)                     as last_visit_in_window,
        {{ lookback_days }}                 as window_days
    from recent_visits
    group by 1
)

select * from customer_summary
