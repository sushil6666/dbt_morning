{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_32', 'pre_hook'],
    pre_hook=[
        "ALTER SESSION SET TIMEZONE = 'UTC'",
        "ALTER SESSION SET WEEK_START = 1",
        "ALTER SESSION SET USE_CACHED_RESULT = FALSE"
    ],
    post_hook="{{ reset_query_tag() }}"
) }}

/*
  demo_32_pre_hook
  ----------------
  Demonstrates the pre_hook LIST syntax — multiple session parameters
  applied before the model runs, each as a separate SQL call.

  The three hooks and why they matter:

  1. TIMEZONE = 'UTC'
       Timestamps are interpreted relative to the session timezone.
       Without this, two dbt runs on machines in different timezones
       produce different CONVERT_TIMEZONE() results in the same model.
       Fix: lock every session to UTC before any timestamp arithmetic.

  2. WEEK_START = 1  (Monday — ISO 8601)
       Snowflake default is 0 (Sunday). DATEADD/WEEK and DATE_TRUNC('week')
       both depend on this setting. Theme-park operations run Mon–Sun
       (weekly event schedules, crew rosters, revenue reports all start
       Monday). Without this hook, date_trunc('week', visit_date) anchors
       on Sunday and every weekly bucket is off by one day.
       PROOF: the week_start_day column will always read 'Mon' when this
       hook is active. Remove the hook and re-run — it flips to 'Sun'.

  3. USE_CACHED_RESULT = FALSE
       Snowflake caches result sets and can serve the same bytes for up
       to 24 hours without re-executing the query. For a revenue dashboard
       that refreshes every 15 minutes, a cached result is stale the moment
       new data loads. Disabling the cache guarantees a live re-execution
       every dbt run — mandatory for any financial or compliance model.

  ALTERNATIVE — reusable macro instead of inline strings:
    pre_hook="set_session_params(timezone='UTC', week_start=1, use_cached_result=false)"
    Both approaches produce the same result. Use the list for simple one-off
    settings; use the macro when the same bundle applies to many models.

  HOW TO VERIFY THE WEEK_START HOOK IS WORKING:
    1. Run with hook:    week_start_day should be 'Mon'
    2. Remove hook, re-run: week_start_day flips to 'Sun'
    3. Restore hook, re-run: flips back to 'Mon'
*/

with visit_weeks as (
    select
        date_trunc('week', visit_date)::date        as week_start,
        ticket_type,
        count(*)                                    as visit_count,
        sum(total_visit_spend)                      as total_revenue,
        round(avg(total_visit_spend), 2)            as avg_spend_per_visit,
        round(avg(avg_rating), 2)                   as avg_rating
    from {{ ref('fct_visits') }}
    where total_visit_spend is not null
    group by 1, 2
)

select
    week_start,
    dayname(week_start)                             as week_start_day,  -- 'Mon' proves WEEK_START=1
    ticket_type,
    visit_count,
    total_revenue,
    avg_spend_per_visit,
    avg_rating,
    sum(total_revenue) over (
        partition by ticket_type
        order by week_start
        rows between unbounded preceding and current row
    )                                               as running_revenue_by_type
from visit_weeks
order by week_start, ticket_type
