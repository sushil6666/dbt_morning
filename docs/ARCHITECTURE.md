# dbt_practice — Architecture Reference

> **Target warehouse:** Snowflake  
> **dbt runtime:** dbt-fusion 2.0 (preview)  
> **Profile:** `dbt_batch`  
> **Project version:** 1.0.0

---

## Table of Contents

1. [Overview](#1-overview)
2. [Layer Architecture](#2-layer-architecture)
3. [Project Directory Structure](#3-project-directory-structure)
4. [Data Sources](#4-data-sources)
5. [Staging Layer](#5-staging-layer)
6. [Intermediate Layer](#6-intermediate-layer)
7. [Marts — Core Layer](#7-marts--core-layer)
8. [Marts — Analytics Layer](#8-marts--analytics-layer)
9. [Utilities](#9-utilities)
10. [Snapshots](#10-snapshots)
11. [Lineage Diagram](#11-lineage-diagram)
12. [Naming Conventions](#12-naming-conventions)
13. [Materialization Strategy](#13-materialization-strategy)
14. [Schema Layout in Snowflake](#14-schema-layout-in-snowflake)
15. [dbt Packages](#15-dbt-packages)
16. [Custom Macro](#16-custom-macro)
17. [Project Variables](#17-project-variables)
18. [Tags Reference](#18-tags-reference)

---

## 1. Overview

This project models a **Theme Park Analytics** platform. Raw operational seed data
(customers, rides, tickets, sales, employees, feedback, haunted events) flows through
a multi-layer dbt pipeline and is served as dimensional models and aggregated analytics
marts to BI tools and data consumers.

```
Seeds (RAW schema)
    └── Staging (cleaned views, one per source domain)
            └── Intermediate (ephemeral business logic joins)
                    └── Marts / Core (dims + facts, tables)
                    └── Marts / Analytics (agg_ tables, BI-ready)
                    └── Utilities (dim_dates, MetricFlow spine)
Snapshots (slowly-changing dimension history)
```

---

## 2. Layer Architecture

| Layer | Prefix | Materialization | Schema | Purpose |
|---|---|---|---|---|
| Staging | `stg_` | view | `staging` | 1-to-1 source cleaning, type casting, renaming |
| Intermediate | `int_` | ephemeral | `intermediate` | Multi-source joins, business logic, no direct BI access |
| Marts — Core | `dim_` / `fct_` | table | `marts` | Conformed dimensions and facts for reporting |
| Marts — Analytics | `agg_` | table | `marts` | Pre-aggregated BI-facing summaries |
| Utilities | _(none)_ | table | `utilities` | Shared date spine and MetricFlow time spine |
| Snapshots | `snp_` | snapshot | `snapshots` | Type-2 SCD history for slowly-changing entities |

---

## 3. Project Directory Structure

```
dbt_practice/
├── models/
│   ├── sources.yml                        # All source definitions
│   ├── staging/
│   │   ├── customer_data/                 # stg_customer_data__*
│   │   ├── external_haunted/              # stg_external_haunted__*
│   │   ├── feedback/                      # stg_feedback__*
│   │   ├── park_assets/                   # stg_park_assets__* + stg_employees__*
│   │   └── sales/                         # stg_sales__* + stg_sales_transactions__*
│   ├── intermediate/                      # int_* (ephemeral)
│   ├── marts/
│   │   ├── core/                          # dim_* + fct_*
│   │   └── analytics/                     # agg_*
│   └── utilities/                         # dim_dates, metricflow_time_spine
├── snapshots/                             # snp_* (Type-2 SCD history)
├── seeds/                                 # Raw CSV data loaded to RAW schema
├── macros/
│   └── generate_schema_name.sql           # Custom schema routing macro
├── packages.yml                           # Package dependencies
├── dbt_project.yml                        # Project configuration
└── models/sources.yml                     # Source definitions with freshness & meta
```

---

## 4. Data Sources

All raw data is loaded via **dbt seeds** into the `RAW` Snowflake schema.
Domain-specific source aliases map logical names to the same underlying tables.

### 4.1 Raw Source Tables

| Table | Description | PII | Freshness Anchor |
|---|---|---|---|
| `raw_customers` | Guest master records | Yes | `created_at` |
| `raw_rides` | Ride and attraction catalog | No | _(no timestamp)_ |
| `raw_tickets` | Ticket purchase transactions | No | `purchase_date` |
| `raw_sales_transactions` | In-park POS transactions | No | `visit_date` |
| `raw_employees` | Employee roster and compensation | Yes | _(no timestamp)_ |
| `raw_feedback` | Post-visit guest feedback | No | `submitted_at` |
| `raw_haunted_events` | External haunted event bookings | No | _(no timestamp)_ |

### 4.2 Domain Source Aliases

| Source Name | Points To | Domain Owner | Used By |
|---|---|---|---|
| `customer_data` | `raw_customers` | guest_services | `stg_customer_data__*` |
| `park_assets` | `raw_rides`, `raw_tickets` | operations | `stg_park_assets__*` |
| `sales` | `raw_tickets` (split by channel) | revenue | `stg_sales__tickets` |
| `sales_transactions` | `raw_sales_transactions` | revenue | `stg_sales_transactions__*` |
| `feedback` | `raw_feedback` | guest_services | `stg_feedback__visitor_feedback` |
| `external_haunted` | `raw_rides`, `raw_tickets` | operations | `stg_external_haunted__*` |
| `employees` | `raw_employees` | hr | `stg_employees__*` |

### 4.3 Freshness Thresholds (pending dbt-fusion support)

| Source | Warn After | Error After |
|---|---|---|
| `raw_tickets`, `raw_sales_transactions`, `haunted_house_tickets` | 1 day | 3 days |
| `raw_feedback` | 3 days | 7 days |
| `raw_customers` | 7 days | 30 days |
| `raw_rides`, `raw_employees`, `raw_haunted_events` | disabled | — |

---

## 5. Staging Layer

**Materialization:** view  
**Schema:** `staging`  
**Convention:** `stg_<source_domain>__<table_name>`

Each staging model performs:
- Column renaming to snake_case standards
- Type casting
- Basic null handling
- No joins — strictly one source table per model

### 5.1 customer_data domain

| Model | Source | Description |
|---|---|---|
| `stg_customer_data__customers` | `customer_data.customers` | Cleaned guest master records |

### 5.2 park_assets domain

| Model | Source | Description |
|---|---|---|
| `stg_park_assets__rides` | `park_assets.rides` | Full ride catalog, all statuses |
| `stg_park_assets__ticket_types` | `park_assets.ticket_types` | Distinct ticket product types |
| `stg_employees__employees` | `employees.employees` | Cleaned employee roster |

### 5.3 sales domain

| Model | Source | Description |
|---|---|---|
| `stg_sales__tickets` | `sales.ticket_sales_online` + `sales.ticket_sales_physical` | All ticket purchases (union of online + physical channels) |
| `stg_sales__ticket_sales_online` | `sales.ticket_sales_online` | Online channel only |
| `stg_sales__ticket_sales_physical` | `sales.ticket_sales_physical` | In-park/kiosk/phone channel only |
| `stg_sales_transactions__sales_transactions` | `sales_transactions.sales_transactions` | In-park POS line items |

### 5.4 feedback domain

| Model | Source | Description |
|---|---|---|
| `stg_feedback__visitor_feedback` | `feedback.visitor_feedback` | General feedback used by intermediate models |
| `stg_feedback__haunted_visitor_feedback` | `feedback.visitor_feedback` | Haunted-house scoped feedback with enriched schema, used by analytics marts |

> **Note:** Both feedback models source the same underlying table but serve different
> consumers with different output schemas and transformations.

### 5.5 external_haunted domain

| Model | Source | Description |
|---|---|---|
| `stg_external_haunted__haunted_houses` | `external_haunted.haunted_houses` | Haunted rides (filtered from raw_rides where `is_haunted = true`) |
| `stg_external_haunted__haunted_house_tickets` | `external_haunted.haunted_house_tickets` | Haunted house ticket sales |

---

## 6. Intermediate Layer

**Materialization:** ephemeral  
**Schema:** `intermediate` _(not written to Snowflake — inlined at query time)_  
**Convention:** `int_<description>`

Intermediate models contain multi-source joins and reusable business logic.
They are never queried directly by BI tools.

| Model | Upstream Sources | Description |
|---|---|---|
| `int_customer_visits` | `stg_sales__tickets`, `stg_sales_transactions__sales_transactions`, `stg_feedback__visitor_feedback` | Joins ticket purchases, in-park spend, and feedback per customer visit |
| `int_daily_revenue` | `stg_sales__tickets`, `stg_sales_transactions__sales_transactions` | Aggregates daily revenue from ticket sales and in-park transactions |
| `int_ride_metrics` | `stg_park_assets__rides`, `stg_feedback__visitor_feedback` | Joins ride catalog with aggregated feedback ratings per ride |

---

## 7. Marts — Core Layer

**Materialization:** table  
**Schema:** `marts`  
**Tags:** `core`

The core layer follows a **star schema** design with conformed dimensions and facts.

### 7.1 Dimensions

| Model | Upstream | Surrogate Key | Description |
|---|---|---|---|
| `dim_customers` | `stg_customer_data__customers` | `customer_id` | Customer dimension with segmentation and lifecycle metrics |
| `dim_rides` | `int_ride_metrics` | `ride_key` | Ride dimension with aggregated ratings and review counts |
| `dim_employees` | `stg_employees__employees` | `employee_key` | Employee dimension with manager hierarchy and tenure |
| `dim_ticket_types` | `stg_park_assets__ticket_types` | _(ticket_id)_ | Ticket product dimension |
| `dim_transaction_flags` | `fct_all_ticket_sales` | _(junk dimension)_ | Junk dimension of boolean transaction flags |

### 7.2 Facts

| Model | Upstream | Grain | Description |
|---|---|---|---|
| `fct_visits` | `int_customer_visits`, `dim_dates` | One row per customer visit | Visit-level fact with ticket and total spend amounts |
| `fct_sales` | `stg_sales_transactions__sales_transactions`, `dim_dates` | One row per POS line item | In-park sales transactions with date dimension join |
| `fct_all_ticket_sales` | `stg_sales__ticket_sales_online`, `stg_sales__ticket_sales_physical` | One row per ticket sale | Union of all ticket sales across all channels |
| `fct_haunted_house_tickets` | `stg_external_haunted__haunted_house_tickets`, `stg_external_haunted__haunted_houses` | One row per haunted house ticket | Haunted house ticket fact with house dimension |
| `fct_sales_with_junk_key` | `fct_all_ticket_sales`, `dim_transaction_flags` | One row per ticket sale | Ticket sales fact enriched with junk dimension key |

---

## 8. Marts — Analytics Layer

**Materialization:** table  
**Schema:** `marts`  
**Tags:** `analytics`  
**Convention:** `agg_<subject>`

Pre-aggregated, BI-ready models. Most analytics models consume the haunted-house
specific feedback model (`stg_feedback__haunted_visitor_feedback`).

| Model | Upstream | Description |
|---|---|---|
| `agg_customer_lifetime_value` | `dim_customers`, `fct_all_ticket_sales` | CLV per customer segment |
| `agg_customer_spending_profile` | `stg_feedback__haunted_visitor_feedback` | Spending patterns by customer profile |
| `agg_daily_revenue` | `int_daily_revenue`, `dim_dates` | Daily revenue trends with date attributes |
| `agg_fear_vs_ratings` | `stg_feedback__haunted_visitor_feedback` | Correlation between fear level and guest ratings |
| `agg_halloween_spending` | `fct_all_ticket_sales`, `dim_dates` | Spending analysis during Halloween season |
| `agg_happiest_houses` | `stg_feedback__haunted_visitor_feedback` | Highest-rated haunted houses |
| `agg_house_profitability_by_time` | `stg_feedback__haunted_visitor_feedback` | Haunted house revenue by time period |
| `agg_ride_popularity` | `dim_rides` | Ride popularity ranked by visit volume and ratings |
| `agg_ticket_value` | `stg_feedback__haunted_visitor_feedback` | Ticket value perception from guest feedback |
| `agg_vip_satisfaction` | `stg_feedback__haunted_visitor_feedback` | Satisfaction scores for VIP / platinum tier guests |
| `agg_visitor_recommendations` | `stg_feedback__haunted_visitor_feedback` | Guest recommendation likelihood by house and segment |

---

## 9. Utilities

**Materialization:** table  
**Schema:** `utilities`

| Model | Description |
|---|---|
| `dim_dates` | Full date dimension generated via `dbt_utils.date_spine` from `date_spine_start` to `date_spine_end`. Includes year, quarter, month, day, weekday, weekend flag, Halloween flag, days-to-Halloween, and business season. |
| `metricflow_time_spine` | Minimal single-column date table (`date_day`) required by the dbt Semantic Layer / MetricFlow for time-series metric definitions. |

**`dim_dates` columns:**

| Column | Description |
|---|---|
| `date_day` | Calendar date |
| `year` / `year_number` | 4-digit year |
| `month_number` | Month as integer (1–12) |
| `month_name` | Month name (Jan–Dec) |
| `day_number` | Day of month |
| `day_of_week_number` | Day of week as integer |
| `day_of_week` | Day name (Mon–Sun) |
| `quarter` | Quarter (1–4) |
| `is_weekend` | Boolean |
| `is_halloween` | True when month=10 and day=31 |
| `days_to_halloween` | Signed integer: positive = days until Oct 31 |
| `business_season` | Summer / Halloween Season / Winter / Spring / Fall |

---

## 10. Snapshots

**Materialization:** snapshot (Type-2 SCD using `check` strategy)  
**Schema:** `snapshots`  
**Convention:** `snp_<entity>`

All snapshots use the `check` strategy (tracks any column value change).

| Snapshot | Source Model | Unique Key | What It Tracks |
|---|---|---|---|
| `snp_customers` | `stg_customer_data__customers` | `customer_id` | Customer attribute changes (membership tier, active status, etc.) |
| `snp_haunted_house_attributes` | `stg_external_haunted__haunted_houses` | `haunted_house_id` | Haunted house attribute changes (fear level, name, status) |
| `snp_product_pricing_history` | `stg_park_assets__ticket_types` | `ticket_id` | Ticket pricing changes over time |
| `snp_ticket_sales_history` | `fct_all_ticket_sales` | `sale_id` | Historical state of ticket sale records |
| `snp_visitor_feedback_changes` | `stg_feedback__haunted_visitor_feedback` | `feedback_id` | Feedback record mutations (rating corrections, sentiment re-classification) |

---

## 11. Lineage Diagram

```
RAW SEEDS
├── raw_customers
│   └── stg_customer_data__customers ──────────────────────────► dim_customers
│   │                                                                  │
│   └── (via customer_data source) ─── snp_customers                  │
│                                                              agg_customer_lifetime_value ◄─ fct_all_ticket_sales
│
├── raw_rides
│   ├── stg_park_assets__rides ─────────► int_ride_metrics ──► dim_rides ──► agg_ride_popularity
│   └── stg_external_haunted__haunted_houses ───────────────────────────────► fct_haunted_house_tickets
│                                          └── snp_haunted_house_attributes
│
├── raw_tickets
│   ├── stg_sales__tickets ─────────────► int_customer_visits ──► fct_visits
│   │                                  └► int_daily_revenue ────► agg_daily_revenue
│   ├── stg_sales__ticket_sales_online ─► fct_all_ticket_sales ─► fct_sales_with_junk_key
│   ├── stg_sales__ticket_sales_physical ─►                         │
│   ├── stg_park_assets__ticket_types ──► dim_ticket_types          └── dim_transaction_flags
│   └── stg_external_haunted__haunted_house_tickets ──────────────► fct_haunted_house_tickets
│                                                    └── snp_ticket_sales_history
│
├── raw_sales_transactions
│   └── stg_sales_transactions__sales_transactions ─► int_customer_visits ──► fct_visits
│                                                  └► int_daily_revenue
│                                                  └► fct_sales
│
├── raw_employees
│   └── stg_employees__employees ──────────────────────────────────► dim_employees
│
├── raw_feedback
│   ├── stg_feedback__visitor_feedback ─► int_ride_metrics
│   │                                  └► int_customer_visits
│   └── stg_feedback__haunted_visitor_feedback ──────────────────► agg_fear_vs_ratings
│                                              └────────────────► agg_happiest_houses
│                                              └────────────────► agg_halloween_spending (via fct_all_ticket_sales)
│                                              └── snp_visitor_feedback_changes
│
└── (dim_dates / metricflow_time_spine)
    ├── fct_visits ◄── dim_dates
    ├── fct_sales  ◄── dim_dates
    └── agg_daily_revenue ◄── dim_dates
```

---

## 12. Naming Conventions

| Layer | Convention | Example |
|---|---|---|
| Staging | `stg_<source_domain>__<table>` | `stg_sales__tickets` |
| Intermediate | `int_<description>` | `int_daily_revenue` |
| Dimension | `dim_<entity>` | `dim_customers` |
| Fact | `fct_<event>` | `fct_visits` |
| Aggregate | `agg_<subject>` | `agg_daily_revenue` |
| Snapshot | `snp_<entity>` | `snp_customers` |
| Double underscore | Separates source domain from table name in staging | `stg_park_assets__rides` |

---

## 13. Materialization Strategy

| Layer | Materialization | Rationale |
|---|---|---|
| Staging | `view` | No storage cost; always reflects latest source data |
| Intermediate | `ephemeral` | Business logic inlined into downstream queries; avoids intermediate tables |
| Marts (core + analytics) | `table` | Pre-computed for BI performance; stable schema for consumers |
| Utilities | `table` | Date spine queried frequently; must be persistent |
| Snapshots | `snapshot` | dbt-managed SCD Type-2 history tables |

---

## 14. Schema Layout in Snowflake

```
<database>
├── RAW                    ← dbt seed tables (raw_customers, raw_rides, etc.)
├── STAGING                ← stg_* views
├── MARTS                  ← dim_*, fct_*, agg_* tables
├── UTILITIES              ← dim_dates, metricflow_time_spine
├── SNAPSHOTS              ← snp_* snapshot tables
└── DBT_BATCH_DEV          ← legacy schema (do not build against)
```

> Schema routing is controlled by the custom `generate_schema_name` macro which uses
> the `custom_schema_name` directly (without prefixing the target schema), keeping
> Snowflake schema names clean across dev and prod targets.

---

## 15. dbt Packages

| Package | Version | Purpose |
|---|---|---|
| `dbt-labs/dbt_utils` | `>=1.1.0, <2.0.0` | `generate_surrogate_key`, `date_spine`, general SQL utils |
| `calogica/dbt_expectations` | `>=0.10.0, <1.0.0` | Expectation-style data quality tests (`expect_column_values_to_be_between`, etc.) |
| `dbt-labs/dbt_project_evaluator` | `>=0.13.0, <1.0.0` | Enforces dbt best practices (naming, coverage, fan-out rules) |
| `elementary-data/elementary` | `>=0.16.0, <1.0.0` | dbt run/test observability and anomaly monitoring |
| `dbt-labs/dbt_audit_helper` | `0.12.0` (git) | Compare model outputs between runs for safe refactors |

---

## 16. Custom Macro

### `generate_schema_name`

**File:** `macros/generate_schema_name.sql`

Overrides dbt's default schema naming behaviour. By default dbt prefixes custom
schema names with the target schema (e.g., `dev_staging`). This macro removes the
prefix so schemas resolve cleanly:

| `custom_schema_name` set? | Result |
|---|---|
| No | Uses `target.schema` (default) |
| Yes | Uses `custom_schema_name` as-is (e.g., `staging`, `marts`) |

This ensures schema names are identical in dev and prod, controlled purely by
the `+schema:` config in `dbt_project.yml`.

---

## 17. Project Variables

Defined in `dbt_project.yml` and used by `dim_dates` and `metricflow_time_spine`:

| Variable | Default | Purpose |
|---|---|---|
| `date_spine_start` | `'2020-01-01'` | First date in the generated date dimension |
| `date_spine_end` | `'2026-12-31'` | Last date in the generated date dimension |

Override at runtime:
```bash
dbt build --vars '{"date_spine_start": "2019-01-01", "date_spine_end": "2027-12-31"}'
```

---

## 18. Tags Reference

| Tag | Applied To | Select With |
|---|---|---|
| `staging` | All staging models | `dbt build --select tag:staging` |
| `customer_data` | `stg_customer_data__*` | `dbt build --select tag:customer_data` |
| `park_assets` | `stg_park_assets__*` | `dbt build --select tag:park_assets` |
| `sales` | `stg_sales__*` | `dbt build --select tag:sales` |
| `external_haunted` | `stg_external_haunted__*` | `dbt build --select tag:external_haunted` |
| `feedback` | `stg_feedback__*` | `dbt build --select tag:feedback` |
| `intermediate` | All intermediate models | `dbt build --select tag:intermediate` |
| `marts` | All mart models | `dbt build --select tag:marts` |
| `core` | `dim_*` + `fct_*` | `dbt build --select tag:core` |
| `analytics` | `agg_*` | `dbt build --select tag:analytics` |
| `utilities` | `dim_dates`, `metricflow_time_spine` | `dbt build --select tag:utilities` |
