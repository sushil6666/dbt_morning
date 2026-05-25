{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'append',
        on_schema_change     = 'append_new_columns',
        full_refresh         = false,
        cluster_by           = ['visit_date'],
        tags                 = ['macro_demo', 'demo_22', 'incremental', 'append']
    )
}}

{#
  STRATEGY: append
  -----------------------------------------------------------------------
  Appends new in-park sales transactions to a growing ledger.
  No MERGE — no deduplication — pure INSERT INTO ... SELECT.

  WHY APPEND IS SAFE HERE:
    Sales transactions are immutable once posted. A transaction_id
    is never updated or corrected — adjustments create a new offsetting row.
    Using merge would pay for a MATCHED check that can never fire.

  WATERMARK COLUMN: visit_date
    visit_date is the closest thing to an event timestamp in this model.
    Strict > excludes the already-loaded boundary date.
    coalesce('1900-01-01') loads all rows on first run.

  _loaded_at:
    Audit column stamped at query time. Allows detecting rows that were
    accidentally re-ingested (e.g., pipeline replay) by comparing
    _loaded_at batches for the same visit_date range.

  on_schema_change = 'append_new_columns':
    New columns added upstream will be added to the target table on the
    next run. 'sync_all_columns' is intentionally avoided here — removing
    a column from an append-only ledger would destroy historical data.

  full_refresh = false:
    Prevents dbt run --full-refresh from truncating and rebuilding this
    table. An append-only ledger must never be wiped; this config makes
    that guarantee explicit. Overriding requires deleting the target table
    directly in Snowflake.

  DO NOT use append for mutable sources (orders, users, subscriptions).
  Any column that changes after insertion makes append produce stale data.
#}

with source as (

    select
        sales_key,
        transaction_id,
        customer_id,
        visit_date,
        day_of_week,
        month_name,
        quarter,
        year,
        is_weekend,
        category,
        item_name,
        quantity,
        unit_price,
        total_amount,
        payment_method,
        location,
        _loaded_at
    from {{ ref('demo_22_sample_append') }}

    {% if is_incremental() %}
        where visit_date > (
            select coalesce(max(visit_date), '1900-01-01'::date) from {{ this }}
        )
    {% endif %}

)

select * from source
