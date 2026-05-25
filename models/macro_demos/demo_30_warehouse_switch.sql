{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_30', 'warehouse'],
    pre_hook="{{ switch_warehouse(var('heavy_model_warehouse', 'DBT_WH')) }}",
    post_hook="{{ reset_warehouse() }}"
) }}

/*
  demo_30_warehouse_switch
  ------------------------
  Real-world pattern: per-model warehouse sizing for compute-heavy models.

  This model runs multiple window functions over the full visit fact table
  (unbounded frame running total + dense_rank + partition average). On large
  datasets these spill to disk on an XS warehouse, blowing SLAs.

  Solution: pre_hook switches to a larger warehouse just for this model;
  post_hook resets to the profile default so all other models in the run
  are unaffected.

    Execution flow:
      1. pre_hook  → USE WAREHOUSE COMPUTE_WH_LARGE  (or var override)
      2. dbt materialises the table (window functions run on large WH)
      3. post_hook → USE WAREHOUSE COMPUTE_WH        (profile default)

  Override warehouse from CLI:
    dbt run --vars '{"heavy_model_warehouse": "DBT_WH_LARGE"}' \
            --select demo_30_warehouse_switch

  WHY VAR NOT HARDCODE:
    dev uses DBT_WH, prod can use a larger warehouse.
    A var keeps the model portable across environments without profiles
    carrying model-specific warehouse logic.

  SNOWFLAKE NOTE:
    USE WAREHOUSE switches the session warehouse only — other concurrent
    sessions are unaffected. Billing on the new warehouse starts immediately
    and stops when the session switches back or closes.
*/

with visit_metrics as (
    select
        customer_id,
        ticket_type,
        visit_date,
        total_visit_spend,
        avg_rating,

        -- Running cumulative spend per customer (ordered by visit date)
        sum(total_visit_spend) over (
            partition by customer_id
            order by visit_date
            rows between unbounded preceding and current row
        )                                               as running_total_spend,

        -- Rank within each ticket type by visit spend (1 = highest spender)
        dense_rank() over (
            partition by ticket_type
            order by total_visit_spend desc
        )                                               as spend_rank_in_ticket_type,

        -- Average spend for the same ticket type across all visits
        avg(total_visit_spend) over (
            partition by ticket_type
        )                                               as avg_spend_for_ticket_type

    from {{ ref('fct_visits') }}
    where total_visit_spend is not null
)

select
    customer_id,
    ticket_type,
    visit_date,
    total_visit_spend,
    avg_rating,
    running_total_spend,
    spend_rank_in_ticket_type,
    round(avg_spend_for_ticket_type, 2)                 as avg_spend_for_ticket_type,
    round(total_visit_spend - avg_spend_for_ticket_type, 2) as spend_vs_ticket_avg
from visit_metrics
