{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_07']
) }}

{#
  ──────────────────────────────────────────────────────────────────────
  Write-Audit-Publish (WAP) — zero-downtime schema-level deployment
  ──────────────────────────────────────────────────────────────────────

  PATTERN OVERVIEW
  ┌──────────────────────────────────────────────────────────┐
  │  Step 1 — WRITE    dbt run  --target candidate           │
  │           Builds all models into DBT_BATCH_CANDIDATE     │
  │                                                          │
  │  Step 2 — AUDIT    dbt test --target candidate           │
  │           Runs every test against the candidate data     │
  │                                                          │
  │  Step 3 — PUBLISH  dbt run-operation swap_schemas \      │
  │             --args '{"candidate_schema":                 │
  │                       "DBT_BATCH_CANDIDATE",             │
  │                       "prod_schema": "DBT_BATCH_PROD"}'  │
  │             --target prod                                │
  │           Renames CANDIDATE → PROD (metadata only,       │
  │           sub-millisecond; BI tools see no downtime)     │
  └──────────────────────────────────────────────────────────┘

  HOW swap_schemas WORKS (macros/07_zero_downtime/swap_schemas.sql)
    1. DROP SCHEMA  DBT_BATCH_PROD_BACKUP  (clear previous backup)
    2. RENAME       DBT_BATCH_PROD       → DBT_BATCH_PROD_BACKUP
    3. RENAME       DBT_BATCH_CANDIDATE  → DBT_BATCH_PROD          ← publish
    4. DROP SCHEMA  DBT_BATCH_PROD_BACKUP  (unless keep_backup=true)

  All three renames are Snowflake metadata operations — no data is copied.

  ALTERNATIVE: table-level swap (per-model hooks, macros/07_zero_downtime/zero_downtime_swap.sql)
    config(
        pre_hook  = "{{ pre_swap_clone() }}",
        post_hook = "{{ post_swap_table(this.schema ~ '.demo_07_zero_downtime_staging') }}"
    )
  Use this when you only want WAP for a single high-value table, not the whole schema.
#}

SELECT
    ticket_id,
    customer_id,
    visit_date,
    ticket_type,
    total_visit_spend,
    avg_rating
FROM {{ ref('fct_visits') }}
