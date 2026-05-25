{{
    config(
        materialized          = 'incremental',
        incremental_strategy  = 'merge',
        unique_key            = 'sale_id',
        merge_update_columns  = ['ticket_price', 'discount_percent', 'discount_category', 'updated_at'],
        on_schema_change      = 'sync_all_columns',
        incremental_predicates = ["DBT_INTERNAL_DEST.purchase_date >= dateadd('day', -90, current_date())"],
        cluster_by            = ['purchase_date'],
        tags                  = ['macro_demo', 'demo_21', 'incremental', 'merge']
    )
}}

{#
  STRATEGY: merge
  -----------------------------------------------------------------------
  Keeps ticket sales records current by merging on sale_id.

  - INSERT: new sales not yet in the target
  - UPDATE: only the four price/discount columns, preserving created_at
  - DELETE: none — hard deletes from source are not reflected

  WATERMARK COLUMN: updated_at
    updated_at changes whenever ticket_price or discount_percent changes
    in the upstream source system. Using strict > (not >=) avoids
    reprocessing the boundary row on every run.

  CLUSTER_BY purchase_date:
    Snowflake prunes micro-partitions on the is_incremental() filter
    and on downstream date-range queries.

  merge_update_columns prevents created_at from being overwritten
  on every MATCHED row, which would destroy the original insert time.

  on_schema_change = 'sync_all_columns':
    When a new column is added to fct_all_ticket_sales it will
    automatically appear in the target on the next run. Removed columns
    are also dropped. Use 'append_new_columns' if you want to keep
    old columns when upstream removes them.

  incremental_predicates:
    Limits the scan of the EXISTING target table during the MERGE.
    DBT_INTERNAL_DEST is the alias dbt assigns to the target table.
    Without this, Snowflake must scan all historical rows to find matches.
    Set to 90 days — tune to the max realistic age of an updated row.
#}

with source as (

    select
        sale_id,
        customer_id,
        ticket_id,
        purchase_date,
        visit_date,
        ticket_price,
        discount_percent,
        discount_category,
        visit_hour,
        payment_method,
        purchase_channel,
        is_online,
        same_day_visit,
        advance_purchase,
        visit_time_category,
        business_season,
        created_at,
        updated_at
    from {{ ref('demo_21_sample_merge') }}

    {% if is_incremental() %}
        -- Only fetch rows newer than the latest record already in the target.
        -- coalesce guards against an empty target on the very first incremental run.
        where updated_at > (
            select coalesce(max(updated_at), '1970-01-01'::timestamp) from {{ this }}
        )
    {% endif %}

)

select * from source
