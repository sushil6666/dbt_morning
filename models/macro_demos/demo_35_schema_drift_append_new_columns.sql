{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='sale_id',
        on_schema_change='append_new_columns',
        tags=['macro_demo', 'demo_35', 'schema_drift', 'append_new_columns']
    )
}}

/*
  demo_35_schema_drift_append_new_columns
  ---------------------------------------
  Real-world pattern: allow additive schema evolution without removing legacy
  columns from an existing incremental target.

  WHEN TO USE THIS:
    Choose append_new_columns when upstream producers may add fields over time,
    but you want the existing target shape to remain backwards compatible for
    downstream consumers.

  MODES:
    baseline        → original column set
    add_new_column  → exposes is_deep_discount on the next incremental run

  WHY append_new_columns:
    dbt adds new top-level columns to the existing table, but it does not delete
    older columns if the SQL later stops selecting them. That makes it the safer
    option for semi-published incrementals where compatibility matters.

  IMPORTANT LIMIT:
    Historical rows are not backfilled for new columns. Older rows will keep
    nulls unless you run a full-refresh or perform a manual update.

  Run:
    1) dbt build --select demo_35_schema_drift_append_new_columns
    2) dbt run --select demo_35_schema_drift_append_new_columns \
         --vars '{"demo_35_schema_drift_mode": "add_new_column"}'
*/

{% set drift_mode = var('demo_35_schema_drift_mode', 'baseline') %}

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
    discount_category,
    updated_at
    {% if drift_mode == 'add_new_column' %}
    ,case when discount_percent >= 20 then true else false end as is_deep_discount
    {% endif %}
from source
