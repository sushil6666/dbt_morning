{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key           = 'visit_date',
        on_schema_change     = 'sync_all_columns',
        cluster_by           = ['visit_date'],
        tags                 = ['macro_demo', 'demo_23', 'incremental', 'delete_insert']
    )
}}

{#
  STRATEGY: delete+insert
  -----------------------------------------------------------------------
  Builds a daily visit summary. Each run replaces the last 3 days of
  data so that late-arriving source corrections (re-stated visit records)
  are always reflected.

  HOW IT WORKS:
    1. dbt DELETEs all rows in the target where visit_date matches any
       value in the incoming source batch (the last 3 days).
    2. dbt INSERTs the freshly-aggregated rows for those same dates.
    Both steps run inside a single transaction.

  PARTITION COLUMN (unique_key = 'visit_date'):
    unique_key here is the PARTITION boundary, not a row-level PK.
    All rows sharing a visit_date value are deleted and rewritten together.
    Do NOT set unique_key to a high-cardinality column (e.g. ticket_id)
    — that triggers one DELETE per row, which is as expensive as a full merge.

  LOOK-BACK WINDOW (max(visit_date) - 3 days):
    Source data for T-1 and T-2 may arrive up to 3 days late.
    Reprocessing a 3-day window ensures corrections are absorbed.
    Tune this value to match your upstream SLA.

  CLUSTER_BY visit_date:
    Without clustering, the DELETE scans the entire table for matching
    micro-partitions. Clustering limits the scan to the 3-day window.

  on_schema_change = 'sync_all_columns':
    Because each partition is deleted and fully rewritten, a new column
    added upstream will safely appear in rewritten partitions.
    sync_all_columns is appropriate here — no historical rows are preserved
    between runs that could be left with NULL in the new column.
#}

with daily_visits as (

    select
        visit_date,
        ticket_type,
        unique_visitors,
        total_visits,
        total_ticket_revenue,
        total_in_park_spend,
        total_visit_spend,
        avg_satisfaction_rating,
        min_ticket_price,
        max_ticket_price
    from {{ ref('demo_23_sample_delete_insert') }}

    {% if is_incremental() %}
        -- Reload the last 3 days to absorb upstream corrections and late arrivals
        where visit_date >= (
            select dateadd('day', -3, coalesce(max(visit_date), current_date())) from {{ this }}
        )
    {% endif %}

)

select * from daily_visits
