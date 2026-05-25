{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_20', 'constraints'],
    post_hook="{{ apply_constraints(primary_key='sale_id', unique_keys=['ticket_id'], not_null_columns=['sale_id','customer_id','visit_date','ticket_type'], fk_columns=['customer_id'], fk_ref_models=['dim_customers'], fk_ref_columns=['customer_id']) }}"
) }}

/*
  demo_20_constraints
  -------------------
  Demonstrates the `apply_constraints` macro (macros/16_constraints/apply_constraints.sql).

  Selects a clean visit fact from fct_visits and, after the table is built,
  applies Snowflake DDL constraints via post_hook:

    • PRIMARY KEY  → sale_id   (aliased from fct_visits.visit_key)
    • UNIQUE       → ticket_id (one row per source ticket)
    • NOT NULL     → sale_id, customer_id, visit_date, ticket_type
    • FOREIGN KEY  → customer_id → dim_customers.customer_id

  WHY POST-HOOK:
    ALTER TABLE requires the table to already exist — post_hook is the only
    valid execution window. pre_hook would fail on a fresh build.

  SNOWFLAKE NOTE:
    All four constraint types are metadata-only. Snowflake stores them in
    information_schema but never rejects writes that violate them.
    BI tools (Tableau, Power BI, Looker) read this metadata to auto-infer
    join paths — that is the primary value of declaring constraints.

  ENFORCEMENT:
    Use dbt tests (unique, not_null, relationships) for actual data quality
    enforcement. See schema_demo_20_constraints.yml.
*/

{#- Declare ref at top level so dbt can parse the dependency graph -#}
{%- set _fk_ref = ref('dim_customers') -%}

with base as (
    select
        visit_key       as sale_id,   -- surrogate PK
        ticket_id,
        customer_id,
        visit_date,
        ticket_type,
        ticket_price,
        in_park_spend,
        total_visit_spend,
        avg_rating
    from {{ ref('fct_visits') }}
    where visit_date  is not null
      and customer_id is not null
)

select * from base
