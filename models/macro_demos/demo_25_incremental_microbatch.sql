{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'microbatch',
        event_time           = 'purchase_ts',
        batch_size           = 'day',
        lookback             = 3,
        begin                = '2024-10-01',
        on_schema_change     = 'sync_all_columns',
        cluster_by           = ['purchase_date'],
        tags                 = ['macro_demo', 'demo_25', 'incremental', 'microbatch']
    )
}}

{#
  STRATEGY: microbatch
  -----------------------------------------------------------------------
  Processes ticket sales in discrete daily windows. dbt orchestrates
  the batch loop — each day is compiled and executed as a separate query,
  enabling independent retry and fine-grained observability.

  REQUIRES: dbt-fusion 2.x / dbt-core 1.9+

  HOW IT WORKS:
    dbt determines the batch windows between begin (or last processed ts)
    and now, then for each window injects:
      WHERE purchase_ts >= '<batch_start>' AND purchase_ts < '<batch_end>'
    Each batch is an independent Snowflake query. Failed batches can be
    retried with --event-time-start / --event-time-end CLI flags without
    reprocessing the entire table.

  event_time = 'purchase_ts':
    purchase_date is cast to a timestamp so dbt can perform sub-day
    filtering if batch_size is later changed to 'hour'.
    DO NOT add a manual is_incremental() filter — dbt injects the
    window filter automatically. A manual filter would double-filter rows
    or create gaps.

  lookback = 3:
    Reprocesses the last 3 completed day batches on every run to absorb
    late-arriving source rows. Match this to your upstream SLA.

  begin = '2024-10-01':
    The earliest batch date. On the very first run dbt backfills from
    this date. Use --event-time-start to control the initial load window
    and avoid processing months of history at once.

  CLUSTER_BY purchase_date:
    Aligns Snowflake micro-partitions to daily batch boundaries, minimising
    bytes scanned per batch query.

  on_schema_change = 'sync_all_columns':
    Because Snowflake runs microbatch as delete+insert under the hood,
    each batch window is fully replaced. New upstream columns will appear
    in reprocessed batches; historical batches outside the lookback window
    will have NULL until next reprocessed.

  Snowflake microbatch internals:
    On Snowflake, dbt implements microbatch using the delete+insert
    strategy under the hood — each batch deletes rows in the window
    then inserts the recomputed results. Retry a specific failed batch:
      dbt run --select demo_25_incremental_microbatch \
               --event-time-start '2024-11-01' \
               --event-time-end   '2024-11-02'
#}

select
    sale_id,
    customer_id,
    ticket_id,
    purchase_date,
    purchase_ts,
    visit_date,
    ticket_price,
    discount_percent,
    discount_category,
    payment_method,
    purchase_channel,
    is_online,
    same_day_visit,
    advance_purchase,
    visit_time_category,
    business_season,
    updated_at
from {{ ref('demo_25_sample_microbatch') }}
