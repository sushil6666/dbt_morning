{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_34', 'contract']
) }}

/*
  demo_34_contract_enforced_table
  -------------------------------
  Real-world pattern: enforce a stable published interface on a mart model.

  WHY CONTRACTS EXIST:
    Once a model is consumed by BI, reverse ETL, or downstream marts, changing a
    column name or type becomes a breaking change. An enforced contract makes dbt
    validate the returned dataset before materialisation so interface drift fails
    fast instead of leaking downstream.

  WHY THIS MODEL IS A TABLE:
    Contracts matter most on published surfaces that other tools query directly.
    A table materialisation makes that intent explicit: this is a governed output,
    not just an internal transformation step.

  WHAT THIS DEMO SHOWS:
    • contract enforced in YAML
    • explicit column types on a published model
    • a narrow, consumer-friendly projection over fct_visits

  EXPECTED BEHAVIOUR:
    - If SQL and YAML stay aligned, the model builds normally.
    - If a column is renamed, removed, or changes type, dbt fails before publish.

  Run:
    dbt build --select demo_34_contract_enforced_table
*/

select
    visit_key,
    customer_id,
    visit_date,
    ticket_type,
    cast(total_visit_spend as number(12,2)) as total_visit_spend,
    cast(avg_rating as number(4,2))         as avg_rating
from {{ ref('fct_visits') }}
where visit_date is not null
