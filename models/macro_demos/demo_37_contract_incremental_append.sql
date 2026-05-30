{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='sale_id',
        on_schema_change='append_new_columns',
        tags=['macro_demo', 'demo_37', 'contract', 'incremental']
    )
}}

/*
  demo_37_contract_incremental_append
  ----------------------------------
  Real-world pattern: combine an enforced contract with incremental delivery.

  WHEN TO USE THIS:
    This is the safe pattern for a published incremental mart: keep the interface
    governed with a contract, but allow additive evolution with
    on_schema_change='append_new_columns'.

  MODES:
    baseline        → contracted base column set
    add_new_column  → populates is_deep_discount while keeping the contract valid

  WHY THIS DEMO ALWAYS RETURNS is_deep_discount:
    Enforced contracts require the SQL definition and YAML contract to stay in
    lockstep. The column is therefore always present; the var only controls
    whether it is populated or left null in baseline mode.

  IMPORTANT LIMIT:
    As with any additive incremental change, historical rows are not backfilled.
    Existing rows keep nulls unless you full-refresh or update them manually.

  Run:
    1) dbt build --select demo_37_contract_incremental_append
    2) dbt run --select demo_37_contract_incremental_append \
         --vars '{"demo_37_contract_incremental_mode": "add_new_column"}'
*/

{% set contract_mode = var('demo_37_contract_incremental_mode', 'baseline') %}

with source as (
    select
        sale_id,
        customer_id,
        ticket_id,
        purchase_date,
        visit_date,
        ticket_price,
        discount_percent,
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
    cast(ticket_price as number(10,2))    as ticket_price,
    cast(discount_percent as number(5,2)) as discount_percent,
    updated_at,
    case
        when '{{ contract_mode }}' = 'add_new_column' and discount_percent >= 20 then true
        when '{{ contract_mode }}' = 'add_new_column' then false
        else cast(null as boolean)
    end as is_deep_discount
from source
