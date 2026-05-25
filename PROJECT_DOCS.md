# DBT-SF-code — Project Documentation

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [Repository Structure](#3-repository-structure)
4. [Sources](#4-sources)
5. [Seeds](#5-seeds)
6. [Models](#6-models)
   - [Staging](#61-staging)
   - [Intermediate](#62-intermediate)
   - [Marts — Core](#63-marts--core)
   - [Marts — Analytics](#64-marts--analytics)
   - [Utilities](#65-utilities)
   - [Macro Demos](#66-macro-demos)
7. [Snapshots (SCD Type 2)](#7-snapshots-scd-type-2)
8. [Macros](#8-macros)
9. [Tests](#9-tests)
10. [Packages](#10-packages)
11. [CI/CD Pipeline](#11-cicd-pipeline)
12. [Project Variables](#12-project-variables)
13. [Snowflake Configuration](#13-snowflake-configuration)

---

## 1. Project Overview

**Theme Park Analytics** — a production-pattern dbt project modelling data for a haunted-theme amusement park.

| Field | Value |
|---|---|
| dbt project name | `dbt_practice` |
| dbt version | dbt-snowflake 1.11.3 |
| Profile | `dbt_batch` |
| Warehouse | Snowflake |
| Config version | 2 |

The project covers the full analytics engineering stack: raw seed data → staging → intermediate → marts, plus SCD Type 2 snapshots, custom Snowflake materializations, row-level security, incremental strategies, unit tests, and a CI/CD slim-build pipeline.

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| Warehouse | Snowflake |
| Transformation | dbt (dbt-snowflake 1.11.3) |
| Orchestration | GitHub Actions |
| Observability | Elementary |
| Project health | dbt Project Evaluator (disabled — dbt-fusion incompatibility) |
| Data quality tests | dbt_expectations, dbt_utils |
| Audit/migration | dbt-audit-helper |

---

## 3. Repository Structure

```
DBT-SF-code/
├── models/
│   ├── staging/          # Views — cleaned raw layer
│   ├── intermediate/     # Ephemeral CTEs — business logic
│   ├── marts/
│   │   ├── core/         # Tables — dims and facts
│   │   └── analytics/    # Tables — aggregated reporting
│   ├── utilities/        # Tables — date spine, MetricFlow
│   └── macro_demos/      # Views — 27 educational dbt/Snowflake demos
├── snapshots/            # SCD Type 2 snapshot definitions
├── seeds/                # Raw CSV data (100 rows each)
│   └── macro_demos/      # Sample CSV data for incremental demos
├── macros/               # Custom macros and materializations
├── tests/                # Ad-hoc singular tests
├── analyses/             # Audit queries
├── ci/                   # Snowflake connection profile for CI
├── .github/workflows/    # GitHub Actions CI/CD
├── packages.yml
├── dbt_project.yml
└── PROJECT_DOCS.md       # This file
```

---

## 4. Sources

All sources resolve to `{{ target.database }}.RAW` (populated by dbt seeds).

| Source alias | Table | Description |
|---|---|---|
| `raw` / `customer_data` | `raw_customers` | Guest master records (PII) — customer_id, email, membership_type, signup_channel |
| `raw` / `park_assets` | `raw_rides` | Ride catalog — ride_id, ride_type, thrill_level, zone, is_haunted, capacity_per_hour |
| `raw` / `park_assets` | `raw_tickets` | Ticket purchases — ticket_id, customer_id, ticket_type, channel, base_price, discount, final_price |
| `raw` / `sales_transactions` | `raw_sales_transactions` | In-park POS — transaction_id, customer_id, category, item_name, total_amount, payment_method |
| `raw` / `employees` | `raw_employees` | Employee roster (PII) — employee_id, department, role, hourly_rate, manager_id, zone |
| `raw` / `feedback` | `raw_feedback` | Guest satisfaction — feedback_id, customer_id, ride_id, rating (1–5), sentiment, comments |
| `raw` | `raw_haunted_events` | Special events — event_id, event_name, external_partner, tickets_allocated, revenue |

Domain-specific source aliases (`sales`, `external_haunted`) re-map the same raw tables with filters applied in staging (e.g. `is_haunted = true` for haunted houses, channel splits for online/physical tickets).

**Legacy source** `DBT_DEV`: points to existing tables in `DBT_BATCH_DEV` schema; tests disabled.

---

## 5. Seeds

Seeded with `dbt seed` into schema `raw`.

| File | Rows | Purpose |
|---|---|---|
| `raw_customers.csv` | 100 | Customer master |
| `raw_employees.csv` | 100 | Employee roster |
| `raw_feedback.csv` | 100 | Visitor satisfaction |
| `raw_haunted_events.csv` | 100 | Special haunted events |
| `raw_rides.csv` | 100 | Ride catalog |
| `raw_sales_transactions.csv` | 100 | In-park POS transactions |
| `raw_tickets.csv` | 100 | Ticket purchases |
| `seeds/macro_demos/demo_21_sample_merge.csv` | — | Merge incremental demo data |
| `seeds/macro_demos/demo_22_sample_append.csv` | — | Append incremental demo data |
| `seeds/macro_demos/demo_23_sample_delete_insert.csv` | — | Delete+insert demo data |
| `seeds/macro_demos/demo_24_sample_insert_overwrite.csv` | — | Insert_overwrite demo data |
| `seeds/macro_demos/demo_25_sample_microbatch.csv` | — | Microbatch demo data |

---

## 6. Models

### Materialization defaults

| Layer | Materialization | Tag |
|---|---|---|
| Staging | `view` | `staging` |
| Intermediate | `ephemeral` | `intermediate` |
| Marts — core | `table` | `core` |
| Marts — analytics | `table` | `analytics` |
| Utilities | `table` | `utilities` |
| Macro demos | `view` | `macro_demo` |

---

### 6.1 Staging

Thin cleaning layer. One model per source table. Naming convention: `stg_<source>__<entity>`.

| Model | Source table | Key transformations |
|---|---|---|
| `stg_customer_data__customers` | raw_customers | Type casts, null handling, PII fields passed through |
| `stg_sales__tickets` | raw_tickets (online) | `is_discounted` flag (CASE on discount_amount), channel filter |
| `stg_sales__ticket_sales_online` | raw_tickets | Online channel filter |
| `stg_sales__ticket_sales_physical` | raw_tickets | Physical channel filter |
| `stg_sales_transactions__sales_transactions` | raw_sales_transactions | Category normalisation, type casts |
| `stg_park_assets__rides` | raw_rides | Thrill level standardisation, operational status |
| `stg_park_assets__ticket_types` | raw_tickets | Deduplicated ticket type/product dimension |
| `stg_employees__employees` | raw_employees | Department/role cleaning, manager_id cast |
| `stg_external_haunted__haunted_houses` | raw_rides | `WHERE is_haunted = true` filter |
| `stg_external_haunted__haunted_house_tickets` | raw_tickets | Haunted house ticket filter |
| `stg_feedback__visitor_feedback` | raw_feedback | Rating range validation, sentiment parsing |
| `stg_feedback__haunted_visitor_feedback` | raw_feedback | Feedback joined to haunted rides only |

---

### 6.2 Intermediate

Business logic as ephemeral CTEs — no physical objects created.

| Model | Logic |
|---|---|
| `int_daily_revenue` | FULL OUTER JOIN of ticket revenue + in-park revenue by `visit_date`; COALESCE to 0; food/merch category CASE split |
| `int_ride_metrics` | Enriches ride catalog with `avg_rating`, `positive_review_pct`, `total_reviews` from feedback (WHERE ride_id IS NOT NULL) |
| `int_customer_visits` | Joins tickets + in-park spend + feedback per customer per visit; coalesces NULL in-park spend to 0 |

---

### 6.3 Marts — Core

Conformed dimensions and facts for BI consumption.

#### Dimensions

| Model | Grain | Key columns |
|---|---|---|
| `dim_customers` | One row per customer | customer_id, segmentation, lifecycle metrics |
| `dim_rides` | One row per ride | ride_id, thrill_level, avg_rating, review_count |
| `dim_employees` | One row per employee | employee_id, manager hierarchy, tenure |
| `dim_ticket_types` | One row per ticket product | ticket_id, type, channel, pricing attributes |
| `dim_transaction_flags` | One row per transaction | Classification flags (junk dimension) |

#### Facts

| Model | Grain | Key measures | Notes |
|---|---|---|---|
| `fct_visits` | One row per customer visit | ticket_price, in_park_spend, total_visit_spend, avg_rating | **Model contract enforced** |
| `fct_sales` | One row per POS transaction | total_amount | Includes junk key |
| `fct_all_ticket_sales` | One row per ticket sale | Full ticket attributes | Combines online + physical |
| `fct_haunted_house_tickets` | One row per haunted ticket | Haunted-specific attributes | |
| `fct_sales_with_junk_key` | One row per sale | total_amount + junk key | Joins to dim_transaction_flags |

---

### 6.4 Marts — Analytics

Pre-aggregated reporting models.

| Model | Description |
|---|---|
| `agg_daily_revenue` | Revenue by day with visitor count and per-visitor spend |
| `agg_customer_lifetime_value` | CLV segmented into Gold / Silver / Bronze loyalty tiers |
| `agg_customer_spending_profile` | Per-customer ticket vs in-park spend breakdown |
| `agg_fear_vs_ratings` | Correlation between haunted house fear level and visitor ratings |
| `agg_halloween_spending` | Spending patterns during Halloween season (controlled by `halloween_analysis_start_date` var) |
| `agg_happiest_houses` | Haunted houses ranked by visitor satisfaction (filtered by `min_satisfaction_rating` var) |
| `agg_house_profitability_by_time` | Haunted house profitability trends over time |
| `agg_ride_popularity` | Rides ranked by review volume and avg rating (tiers: Top Rated / Well Rated / Average / Below Average / Not Yet Rated) |
| `agg_ticket_value` | Ticket value analysis across types and purchase channels |
| `agg_vip_satisfaction` | VIP member satisfaction vs general visitors |
| `agg_visitor_recommendations` | Recommendation rates by house and visitor type |

---

### 6.5 Utilities

| Model | Description |
|---|---|
| `dim_dates` | Full date spine 2020-01-01 → 2026-12-31; columns: day_of_week, quarter, business_season, halloween flag. Uses `dbt_utils.date_spine`. |
| `metricflow_time_spine` | Minimal time spine for MetricFlow / Semantic Layer integration |

---

### 6.6 Macro Demos

33 educational models demonstrating dbt and Snowflake-specific features. All materialised in the `macro_demo` schema (views unless noted).

#### Audit & Transformation
| Model | Feature demonstrated |
|---|---|
| `demo_01_audit_columns` | `audit_columns()` macro — injects dbt_updated_at, run_id, model_name, env |
| `demo_02_incremental_filter` | `incremental_filter()` macro — timestamp-based watermark filtering |

#### Data Quality & Security
| Model | Feature demonstrated |
|---|---|
| `demo_03_pii_masking` | `mask_pii()` — hash / redact / partial modes; prod unchanged |
| `demo_04_dynamic_columns` | `dynamic_columns()` — runtime column evolution |
| `demo_05_row_access_policy` | `attach_row_access_policy()` — Snowflake row-level security |
| `demo_08_data_quality` | `data_quality_score()` — composite DQ scoring |

#### Keys & Constraints
| Model | Feature demonstrated |
|---|---|
| `demo_06_surrogate_key` | `cross_db_surrogate_key()` — cross-adapter surrogate key |
| `demo_20_constraints` | `apply_constraints()` — DDL constraints (PK, UNIQUE, FK, NOT NULL) |

#### Operational
| Model | Feature demonstrated |
|---|---|
| `demo_07_zero_downtime` | `zero_downtime_swap()` — atomic table swap with no downtime |
| `demo_09_clustering` | `apply_cluster_by()` — Snowflake CLUSTER BY clause |
| `demo_10_feature_flag` | `feature_flag()` — environment-driven feature toggling |
| `demo_12_date_spine` | `generate_date_spine()` — cross-adapter date series |
| `demo_13_query_tag` | `set_query_tag()` — query labelling for cost attribution |

#### Snowflake Materializations
| Model | Materialization |
|---|---|
| `demo_11_generic_tests` | Custom generic tests (`valid_ticket_types`, `rating_in_range`) |
| `demo_14_scd` | `read_snapshot()` macro for snapshot-backed SCD |
| `demo_15_partitioning` | `partition_config()` — partition strategy |
| `demo_16_temp_table` | Custom `temp_table` materialization |
| `demo_17_hybrid_table` | Custom `hybrid_table` materialization (Snowflake Delta Lake–like) |
| `demo_18_event_table` | Custom `event_table` materialization (Snowflake native) |
| `demo_19_iceberg_table` | Custom `iceberg_table` materialization (Snowflake proprietary) |
| `demo_27_dynamic_table` | Snowflake Dynamic Table (managed SCD, auto-refresh) |

#### Incremental Strategies
| Model | Strategy | Pattern |
|---|---|---|
| `demo_21_incremental_merge` | `merge` | Upsert on sale_id, watermark: updated_at |
| `demo_22_incremental_append` | `append` | Immutable ledger, watermark: visit_date |
| `demo_23_incremental_delete_insert` | `delete+insert` | Daily summary with 3-day look-back |
| `demo_24_incremental_insert_overwrite` | `insert_overwrite` | Monthly rollup, partition-level replacement |
| `demo_25_incremental_microbatch` | `microbatch` | Daily orchestration (requires dbt 1.9+) |

#### Ephemeral
| Model | Description |
|---|---|
| `demo_26_ephemeral_base` | Ephemeral base — spending_tier (low/mid/high) and revenue_category mapping |
| `demo_26_ephemeral_consumer` | View consuming the ephemeral base; aggregates to revenue summary |

#### Variables
| Model | Feature demonstrated |
|---|---|
| `demo_28_var_date_window` | `var('lookback_days', 90)` — configurable rolling window; `window_days` stamped on every row |
| `demo_29_var_spend_tiers` | `var('spend_tier_high', 300)` / `var('spend_tier_mid', 100)` — finance-owned threshold variables |
| `demo_30_warehouse_switch` | `switch_warehouse()` / `reset_warehouse()` pre/post hook pair — per-model compute sizing |
| `demo_31_var_dev_limit` | `var('dev_row_limit', none)` — environment-aware row capping; never set in `dbt_project.yml` |

#### Hooks
| Model | Feature demonstrated |
|---|---|
| `demo_32_pre_hook` | `pre_hook` list syntax — three session params: `TIMEZONE`, `WEEK_START=1`, `USE_CACHED_RESULT=FALSE`; `week_start_day` column proves hook fired |
| `demo_33_audit_hooks` | `log_model_start()` pre-hook + `log_model_end()` post-hook — writes structured audit record to `SF_TEST.AUDIT.DBT_RUN_LOG` with row count and elapsed time |

---

## 7. Snapshots (SCD Type 2)

All snapshots target schema `snapshots`. Records deleted from source have `dbt_valid_to` stamped when `invalidate_hard_deletes = true`.

| Snapshot | Unique key | Strategy | Tracked columns | Hard-delete invalidation |
|---|---|---|---|---|
| `snp_customers` | `customer_id` | `check` | first_name, last_name, email, phone, address, city, state, zip_code, is_vip_member, marketing_opt_in, loyalty_points | **Yes** |
| `snp_employees` | `employee_id` | `timestamp` | updated_at | No |
| `snp_rides` | `ride_id` | `timestamp` | updated_at | No |
| `snp_ticket_sales_history` | `sale_id` | `check` | ticket_price, discount_percent, payment_method | No |
| `snp_product_pricing_history` | `ticket_id` | `check` | price, includes_fast_pass, includes_vip_benefits, fear_level, duration_minutes | No |
| `snp_haunted_house_attributes` | `haunted_house_id` | `check` | haunted_house_name, capacity, fear_level | No |
| `snp_visitor_feedback_changes` | `feedback_id` | `check` | satisfaction_rating, would_recommend | No |

**SCD columns added by dbt:** `dbt_scd_id` (surrogate), `dbt_valid_from`, `dbt_valid_to`, `dbt_updated_at`.

---

## 8. Macros

### Core metadata & audit
| Macro | Purpose |
|---|---|
| `audit_columns()` | Injects `dbt_updated_at`, `dbt_run_id`, `dbt_model_name`, `dbt_env` metadata columns |
| `generate_schema_name()` | Custom schema naming — overrides dbt default to use `target.schema` |

### Data quality & PII
| Macro | Purpose |
|---|---|
| `mask_pii(column, mask_type)` | Masks PII in dev/staging/ci environments; pass-through in prod. Modes: `hash`, `redact`, `partial` |
| `data_quality_score()` | Computes a composite data quality score for a model |

### Schema evolution & access control
| Macro | Purpose |
|---|---|
| `dynamic_columns()` | Runtime column evolution without model rebuilds |
| `attach_row_access_policy()` | Attaches Snowflake row-level security policy to a table |

### Keys & identifiers
| Macro | Purpose |
|---|---|
| `cross_db_surrogate_key()` | Cross-adapter surrogate key generation (compatible across Snowflake, Postgres, BigQuery) |
| `apply_constraints()` | Attaches DDL constraints: PK, UNIQUE, FK, NOT NULL |

### Operational
| Macro | Purpose |
|---|---|
| `incremental_filter()` | Watermark-based filter for incremental models |
| `zero_downtime_swap()` | Atomic swap of a table with no downtime window |
| `apply_cluster_by()` | Adds Snowflake `CLUSTER BY` clause to a model |
| `feature_flag()` | Toggles logic based on env var or config flag |
| `set_query_tag()` | Sets Snowflake query tag for cost/usage attribution |
| `read_snapshot()` | Reads a snapshot as a slowly-changing dimension |
| `partition_config()` | Configures partition strategy on a model |

### Date & temporal
| Macro | Purpose |
|---|---|
| `generate_date_spine(start, end)` | Cross-adapter date series (Snowflake: GENERATOR+DATEADD; Postgres: GENERATE_SERIES; BigQuery: GENERATE_DATE_ARRAY) |

### Warehouse & session management
| Macro | Purpose |
|---|---|
| `switch_warehouse(warehouse)` | Pre-hook: `USE WAREHOUSE <warehouse>` — scales up for compute-heavy models |
| `reset_warehouse()` | Post-hook: `USE WAREHOUSE {{ target.warehouse }}` — restores profile default after model completes |
| `set_session_params(timezone, week_start, use_cached_result)` | Pre-hook: bundles `TIMEZONE`, `WEEK_START`, and `USE_CACHED_RESULT` session settings in one `EXECUTE IMMEDIATE` call |

### Audit hooks
| Macro | Purpose |
|---|---|
| `log_model_start()` | Pre-hook: creates `SF_TEST.AUDIT.DBT_RUN_LOG` if absent; inserts `status='running'` record with `started_at` and `invocation_id` |
| `log_model_end()` | Post-hook: updates the log record to `status='success'` with `rows_loaded=COUNT(*)` and `elapsed_seconds` |

### Custom materializations (Snowflake-specific)
| Materialization | Purpose |
|---|---|
| `temp_table` | Snowflake temporary table |
| `hybrid_table` | Snowflake Hybrid Table (Delta Lake–like row/column storage) |
| `event_table` | Snowflake Event Table (native audit/event storage) |
| `iceberg_table` | Snowflake Iceberg Table (open table format) |
| `dynamic_table` | Snowflake Dynamic Table (auto-refreshing SCD) |

### Generic tests
| Test | Purpose |
|---|---|
| `test_valid_ticket_types(model, column, valid_types)` | Validates ticket_type against an allowed-values whitelist |
| `test_rating_in_range()` | Asserts rating values fall within expected bounds |
| `test_business_rule()` | Custom business logic assertion |

### Utility helpers
| Macro | Purpose |
|---|---|
| `cast_price()` | Consistent price column casting |
| `spending_tier()` | Bucketing: high ≥ 100, mid 40–99, low < 40 |
| `visit_time_of_day()` | Classifies visit timestamp into time-of-day buckets |
| `create_schema()` | Schema creation helper |
| `create_table_as()` | CREATE TABLE AS wrapper |
| `debug_dim_employees()` | Employee dimension debugging utility |
| `drop_snapshot_tables()` | Cleanup utility for snapshot tables |

---

## 9. Tests

### Schema tests (defined in `schema.yml` files)

| Test type | Models covered |
|---|---|
| `unique` | All PK / surrogate key columns across staging, intermediate, marts, snapshots |
| `not_null` | All key and critical measure columns |
| `accepted_values` | ticket_type, payment_method, sentiment, rating range |
| `relationships` | FK relationships between facts and dimensions |
| `dbt_utils.unique_combination_of_columns` | Composite keys on fact tables |
| `dbt_expectations.expect_column_values_to_be_between` | Rating (1–5), price (≥ 0) |
| `test_valid_ticket_types` | stg_sales__tickets, fct_all_ticket_sales |
| `test_rating_in_range` | stg_feedback__visitor_feedback |

### Unit tests (defined inline in `schema.yml`)

| Test name | Model | What it validates |
|---|---|---|
| `test_is_discounted_flag` | stg_sales__tickets | `is_discounted` CASE logic |
| `test_is_haunted_filter` | stg_external_haunted__haunted_houses | `WHERE is_haunted = true` filter |
| `test_daily_revenue_ticket_only_date` | int_daily_revenue | FULL OUTER JOIN — left-side only rows |
| `test_daily_revenue_sales_only_date` | int_daily_revenue | FULL OUTER JOIN — right-side only rows |
| `test_daily_revenue_category_splitting` | int_daily_revenue | Food/merch CASE splitting |
| `test_ride_metrics_no_reviews` | int_ride_metrics | Zero-review COALESCE handling |
| `test_ride_metrics_positive_review_pct` | int_ride_metrics | `positive_review_pct` = 75% for 3/4 positive reviews |
| `test_ride_metrics_excludes_null_ride_id_feedback` | int_ride_metrics | `WHERE ride_id IS NOT NULL` filter |
| `test_customer_visit_no_inpark_spend` | int_customer_visits | NULL in-park spend coalesces to 0 |
| `test_customer_visit_with_spend_and_feedback` | int_customer_visits | SUM aggregation + multi-table JOIN |
| `test_spending_tier_boundaries` | demo_26_ephemeral_base | high ≥ 100, mid 40–99, low < 40 thresholds |
| `test_revenue_category_ilike_mapping` | demo_26_ephemeral_base | ILIKE pattern mapping (food/bev, merch, ticket, other) |

### Singular tests

| File | Assertion |
|---|---|
| `tests/assert_final_price_non_negative.sql` | No ticket has `final_price < 0` after discount |
| `analyses/audit_stg_tickets.sql` | Audit query for tickets staging layer (not a test — analysis only) |

---

## 10. Packages

| Package | Version | Purpose |
|---|---|---|
| `dbt_utils` | ≥ 1.1.0, < 2.0.0 | Date spine, unique_combination_of_columns, string/array utilities |
| `dbt_expectations` | ≥ 0.10.0, < 1.0.0 | Advanced data quality tests (expect_column_values_to_be_between, etc.) |
| `dbt_project_evaluator` | ≥ 0.13.0, < 1.0.0 | Project health scoring — **disabled** (dbt-fusion incompatibility) |
| `dbt-audit-helper` | git rev 0.12.0 | Row-by-row comparison for migrations and data validation |
| `elementary` | ≥ 0.16.0, < 1.0.0 | Data observability, anomaly detection, schema change monitoring |

Install with: `dbt deps`

---

## 11. CI/CD Pipeline

**File:** `.github/workflows/ci.yml`
**Trigger:** Pull requests and pushes to `main` (in-progress runs cancelled on new push to same branch).

### Required secrets (GitHub → Settings → Secrets)

| Secret | Used for |
|---|---|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier |
| `SNOWFLAKE_USER` | Service account username |
| `SNOWFLAKE_PASSWORD` | Service account password |
| `SNOWFLAKE_ROLE` | Snowflake role (e.g. SYSADMIN) |
| `SNOWFLAKE_DATABASE` | Target database |
| `SNOWFLAKE_WAREHOUSE` | Compute warehouse |

### Jobs

#### 1. Setup (all triggers)
- Checkout repo
- Python 3.12
- `pip install dbt-snowflake`
- `dbt deps`

#### 2. Pull request — Slim CI
- Downloads `manifest.json` artifact from last successful `main` push
- Runs `dbt build --select "state:modified+"` — only changed models and their downstream dependents
- Falls back to full `dbt build` if no prior manifest exists (first PR)

#### 3. Push to main — Full build
- Runs `dbt build` (all models, snapshots, seeds, tests)

#### 4. Results
- Parses `target/run_results.json`
- Writes summary table with counts: pass / success / warn / error / fail / skipped
- Uploads `target/manifest.json` as an artifact (90-day retention) for the next PR's slim CI

---

## 12. Project Variables

Override at runtime with `dbt run --vars '{"var_name": value}'`.

| Variable | Default | Used in | Override example |
|---|---|---|---|
| `date_spine_start` | `'2020-01-01'` | `dim_dates`, `metricflow_time_spine` | `--vars '{"date_spine_start": "2019-01-01"}'` |
| `date_spine_end` | `'2026-12-31'` | `dim_dates`, `metricflow_time_spine` | `--vars '{"date_spine_end": "2027-12-31"}'` |
| `halloween_analysis_start_date` | `'2023-01-01'` | `agg_halloween_spending`, `demo_12_date_spine` | `--vars '{"halloween_analysis_start_date": "2024-01-01"}'` |
| `min_satisfaction_rating` | `3` | `agg_happiest_houses` | `--vars '{"min_satisfaction_rating": 4}'` |
| `bi_role` | `'SYSADMIN'` | `fct_all_ticket_sales` post-hook grant | Set per environment in CI config |
| `lookback_days` | `90` | `demo_28_var_date_window` | `--vars '{"lookback_days": 30}'` |
| `spend_tier_high` | `300` | `demo_29_var_spend_tiers` | `--vars '{"spend_tier_high": 400}'` |
| `spend_tier_mid` | `100` | `demo_29_var_spend_tiers` | `--vars '{"spend_tier_mid": 150}'` |
| `heavy_model_warehouse` | `'DBT_WH'` | `demo_30_warehouse_switch` pre-hook | `--vars '{"heavy_model_warehouse": "DBT_WH_LARGE"}'` |
| `dev_row_limit` | none (no LIMIT) | `demo_31_var_dev_limit` | `--vars '{"dev_row_limit": 500}'` — **never set in `dbt_project.yml`** |

Full variable reference including `env_var()` and `target.*`: see `docs/dbt_variables.md`.

---

## 13. Snowflake Configuration

### Profile (`ci/profiles.yml`)

```yaml
dbt_batch:
  target: ci
  outputs:
    ci:
      type: snowflake
      account:   "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user:      "{{ env_var('SNOWFLAKE_USER') }}"
      password:  "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role:      "{{ env_var('SNOWFLAKE_ROLE') }}"
      database:  "{{ env_var('SNOWFLAKE_DATABASE') }}"
      warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE') }}"
      schema:    PUBLIC
      threads:   8
```

### On-run hooks

**on-run-start:**
```sql
ALTER SESSION SET QUERY_TAG = 'dbt_run_{{ invocation_id }}';
CREATE SCHEMA IF NOT EXISTS {{ target.database }}.INTERMEDIATE;
```

**on-run-end:**
```sql
ALTER SESSION SET QUERY_TAG = '';
```

### Default query tag
All models are tagged with `query_from_dbt` via `+query_tag` config for Snowflake cost attribution.

### Post-hook grants
After mart builds, `SELECT` is granted to the `bi_role` (default: `SYSADMIN`) on all mart tables.

### Schema layout

| Schema | Contains |
|---|---|
| `RAW` | Seeds (raw source data) |
| `PUBLIC` | Default (overridden per layer) |
| `INTERMEDIATE` | Created on-run-start; ephemeral models leave no objects here |
| `SNAPSHOTS` | All SCD Type 2 snapshot tables |
| `ELEMENTARY` | Elementary observability tables |
| `MACRO_DEMOS_SAMPLE` | Seed data for incremental demo models |
| `AUDIT` | `DBT_RUN_LOG` — structured audit log written by `log_model_start()` / `log_model_end()` hook pair |
