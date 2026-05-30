{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='sale_id',
        on_schema_change='sync_all_columns',
        tags=['macro_demo', 'demo_36', 'schema_drift', 'sync_all_columns']
    )
}}

/*
  demo_36_schema_drift_sync_all_columns
  -------------------------------------
  Real-world pattern: keep an incremental target fully aligned to the current
  SQL definition, including both column additions and removals.

  WHEN TO USE THIS:
    Use sync_all_columns for internal working tables where the target schema
    should mirror the latest model definition exactly and downstream consumers
    are not relying on removed columns.

  MODES:
    baseline            → original column set includes discount_category
    add_new_column      → adds is_deep_discount
    drop_legacy_column  → removes discount_category from the target on rerun

  WHY sync_all_columns:
    dbt treats the SQL definition as the source of truth. New columns are added,
    removed columns are dropped, and the target stays tightly aligned to the
    current model code.

  BREAKING-CHANGE WARNING:
    This is not the right setting for published marts. If downstream consumers
    still query a removed column, they will break on the next run.

  Run:
    1) dbt build --select demo_36_schema_drift_sync_all_columns
    2) dbt run --select demo_36_schema_drift_sync_all_columns \
         --vars '{"demo_36_schema_drift_mode": "add_new_column"}'
    3) dbt run --select demo_36_schema_drift_sync_all_columns \
         --vars '{"demo_36_schema_drift_mode": "drop_legacy_column"}'
*/

{% set drift_mode = var('demo_36_schema_drift_mode', 'baseline') %}

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
        updated_at
    from {{ ref('demo_21_sample_merge') }}

    {% if is_incremental() %}
        where updated_at > (
            select coalesce(max(updated_at), '1970-01-01'::timestamp) from {{ this }}
        )
    {% endif %}
)

select
    sale_id,
    customer_id,
    ticket_id,
    purchase_date,
    visit_date,
    ticket_price,
    discount_percent,
    {% if drift_mode != 'drop_legacy_column' %}
    discount_category,
    {% endif %}
    updated_at
    {% if drift_mode == 'add_new_column' %}
    ,case when discount_percent >= 20 then true else false end as is_deep_discount
    {% endif %}
from source
