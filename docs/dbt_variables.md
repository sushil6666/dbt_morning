# dbt Variables — Complete Reference

A comprehensive guide to every variable mechanism used in this project:
`var()`, `env_var()`, `target.*`, and the `feature_flag()` wrapper macro.

---

## 1. The Three Variable Mechanisms

| Mechanism | Resolved by | Typical use |
|-----------|-------------|-------------|
| `var('name', default)` | dbt at compile time | Business thresholds, date windows, feature toggles |
| `env_var('NAME')` | OS environment at profile load | Credentials, account IDs — never in model SQL |
| `target.*` | Active profile target | Environment-aware logic (`target.name`, `target.warehouse`) |

---

## 2. Resolution Priority for `var()`

```
CLI --vars  >  dbt_project.yml vars block  >  in-code default
```

The **rightmost default wins only if nothing above it is set**.
Always supply a sensible default in code (`var('x', <default>)`) so models
run safely without a CLI override.

```bash
# CLI wins — ignores dbt_project.yml value
dbt run --vars '{"lookback_days": 30}' --select demo_28_var_date_window

# dbt_project.yml wins — no CLI override
dbt run --select demo_28_var_date_window   # uses lookback_days: 90

# In-code default wins — not in dbt_project.yml, not in CLI
var('dev_row_limit', none)   # → none  (no LIMIT emitted)
```

---

## 3. All Variables in This Project

### 3.1 Declared in `dbt_project.yml`

| Variable | Default | Type | Used in |
|----------|---------|------|---------|
| `date_spine_start` | `'2020-01-01'` | string (date) | `dim_dates`, `metricflow_time_spine` |
| `date_spine_end` | `'2026-12-31'` | string (date) | `dim_dates`, `metricflow_time_spine` |
| `halloween_analysis_start_date` | `'2023-01-01'` | string (date) | `agg_halloween_spending`, `demo_12_date_spine` |
| `min_satisfaction_rating` | `3` | integer | `agg_happiest_houses` |
| `bi_role` | `'SYSADMIN'` | string | `fct_all_ticket_sales` post-hook |
| `lookback_days` | `90` | integer | `demo_28_var_date_window` |
| `spend_tier_high` | `300` | integer | `demo_29_var_spend_tiers` |
| `spend_tier_mid` | `100` | integer | `demo_29_var_spend_tiers` |
| `heavy_model_warehouse` | `'DBT_WH'` | string | `demo_30_warehouse_switch` pre-hook |

### 3.2 In-Code Defaults Only (not in `dbt_project.yml`)

These are **intentionally absent** from `dbt_project.yml` — a missing default
means the safe behaviour kicks in automatically without a project-level value
that could accidentally bleed into production.

| Variable | In-code default | Used in | Why not in dbt_project.yml |
|----------|----------------|---------|---------------------------|
| `dev_row_limit` | `none` (no LIMIT) | `demo_31_var_dev_limit` | Setting it globally would silently cap prod runs |
| `dev_lookback_days` | `3` (days) | `incremental_filter` macro | Per-engineer preference; not a project-wide constant |
| `cluster_columns` | `['visit_date', 'ticket_type']` | `demo_15_partitioning` | Cluster config belongs in the model, not the project |
| `use_new_pricing_model` | `false` | `demo_10_feature_flag` / `feature_flag()` macro | Feature flags default off; must be explicitly activated |

### 3.3 `env_var()` — Credentials Only (`ci/profiles.yml`)

`env_var()` is used **exclusively** in `profiles.yml` for secrets. It never
appears in model SQL — secrets must not enter the compiled query log.

| Env var | Used for |
|---------|----------|
| `SNOWFLAKE_ACCOUNT` | Snowflake account identifier |
| `SNOWFLAKE_USER` | Service account username |
| `SNOWFLAKE_PASSWORD` | Service account password |
| `SNOWFLAKE_ROLE` | Snowflake role |
| `SNOWFLAKE_DATABASE` | Target database |
| `SNOWFLAKE_WAREHOUSE` | Default virtual warehouse |

Set in GitHub Actions as repository secrets; set locally in your shell
profile or a `.env` file (never commit `.env`).

---

## 4. Patterns — How Variables Are Used in This Project

### 4.1 Rolling Date Window — `demo_28_var_date_window`

**Problem**: Ops dashboards need different lookback windows (30-day sprint,
90-day standard, 365-day churn review) without a code change.

```sql
{% set lookback_days = var('lookback_days', 90) %}

select
    customer_id,
    count(*)         as visit_count,
    {{ lookback_days }} as window_days   -- stamped on every row for BI labels
from {{ ref('fct_visits') }}
where visit_date >= dateadd('day', -{{ lookback_days }}, current_date())
group by 1
```

```bash
# Standard dashboard
dbt run --select demo_28_var_date_window

# Month-end sprint
dbt run --vars '{"lookback_days": 30}' --select demo_28_var_date_window

# Annual churn review
dbt run --vars '{"lookback_days": 365}' --select demo_28_var_date_window
```

**Key technique**: Stamp `window_days` onto every output row so BI tools can
display "Last 30 days" in chart labels without hardcoding the boundary.

---

### 4.2 Business Threshold Variables — `demo_29_var_spend_tiers`

**Problem**: Finance adjusts spend tier boundaries quarterly. Hardcoding them
means a code review for a number change.

```sql
{% set tier_high = var('spend_tier_high', 300) %}
{% set tier_mid  = var('spend_tier_mid',  100) %}

select
    customer_id,
    case
        when total_visit_spend >= {{ tier_high }} then 'High'
        when total_visit_spend >= {{ tier_mid  }} then 'Mid'
        else                                           'Low'
    end                      as spend_tier,
    {{ tier_high }}          as tier_high_threshold,  -- BI label: "High (>=$300)"
    {{ tier_mid  }}          as tier_mid_threshold
from {{ ref('fct_visits') }}
```

```bash
# Q1 thresholds
dbt run --vars '{"spend_tier_high": 400, "spend_tier_mid": 150}' \
        --select demo_29_var_spend_tiers
```

**Key technique**: Write the active threshold values into output columns.
BI reports build labels like `"High (>=$" || tier_high_threshold || ")"` and
stay in sync automatically when thresholds change.

---

### 4.3 Per-Model Warehouse Sizing — `demo_30_warehouse_switch`

**Problem**: One heavy model (full scan + 3 window functions) needs a large
warehouse; changing the profile default penalises all other models.

```sql
{{ config(
    materialized='table',
    pre_hook="{{ switch_warehouse(var('heavy_model_warehouse', 'DBT_WH')) }}",
    post_hook="{{ reset_warehouse() }}"
) }}
```

Macro pair — `macros/17_warehouse/switch_warehouse.sql`:

```sql
{% macro switch_warehouse(warehouse) %}
    {% if execute %} USE WAREHOUSE {{ warehouse }}; {% endif %}
{% endmacro %}

{% macro reset_warehouse() %}
    {% if execute %} USE WAREHOUSE {{ target.warehouse }}; {% endif %}
{% endmacro %}
```

Execution flow for this model only:
```
pre_hook  → USE WAREHOUSE DBT_WH_LARGE
            (window functions run on large WH)
post_hook → USE WAREHOUSE DBT_WH   ← target.warehouse restores profile default
```

```bash
# Override warehouse from CLI
dbt run --vars '{"heavy_model_warehouse": "DBT_WH_LARGE"}' \
        --select demo_30_warehouse_switch
```

**Key technique**: `target.warehouse` in `reset_warehouse()` always restores the
profile-configured warehouse — no hardcoding, works across all environments.

---

### 4.4 Environment-Aware Row Capping — `demo_31_var_dev_limit`

**Problem**: Full-table joins are slow locally. A separate dev seed goes stale
as schema evolves.

```sql
{% set row_limit = var('dev_row_limit', none) %}

select v.customer_id, c.loyalty_tier, v.total_visit_spend, ...
from {{ ref('fct_visits') }} v
inner join {{ ref('dim_customers') }} c on v.customer_id = c.customer_id

{% if row_limit is not none %}
limit {{ row_limit }}
{% endif %}
```

```bash
# Local dev — fast preview
dbt run --vars '{"dev_row_limit": 500}' --select demo_31_var_dev_limit

# Prod — no LIMIT, full data
dbt run --select demo_31_var_dev_limit
```

**Convention**: Never add `dev_row_limit` to `dbt_project.yml`. Set it only in
your local shell or CI step env. A project-level value silently caps prod runs.

---

### 4.5 Feature Flag — `demo_10_feature_flag`

A boolean var wrapped in the `feature_flag()` macro for readable A/B logic.
Lets two implementations coexist in one file without a branch or a separate model.

```sql
-- macros/10_feature_flag/feature_flag.sql
{% macro feature_flag(flag_name, default=false) %}
    {{ var(flag_name, default) | as_bool }}
{% endmacro %}
```

```sql
-- demo_10_feature_flag.sql
select
    ticket_id,
    {% if feature_flag('use_new_pricing_model') %}
        ROUND(final_price * 1.10, 2) AS revenue   -- includes 10% service fee
    {% else %}
        final_price                  AS revenue   -- raw ticket price only
    {% endif %}
from {{ ref('stg_sales__tickets') }}
```

```bash
# Activate new pricing logic
dbt run --vars '{"use_new_pricing_model": true}' --select demo_10_feature_flag

# Revert to old logic (default)
dbt run --select demo_10_feature_flag
```

---

### 4.6 Incremental Filter — `incremental_filter` macro

Combines `var()` with `target.name` for environment-aware incremental watermarks.

```sql
-- macros/02_incremental_filter/incremental_filter.sql
{% macro incremental_filter(timestamp_col, dev_lookback_days=3) %}
    {% if is_incremental() %}
        {% if target.name == 'dev' %}
            {{ timestamp_col }} >= DATEADD(
                day,
                -{{ var('dev_lookback_days', dev_lookback_days) }},
                CURRENT_DATE()
            )
        {% else %}
            {{ timestamp_col }} > (SELECT MAX({{ timestamp_col }}) FROM {{ this }})
        {% endif %}
    {% endif %}
{% endmacro %}
```

| Target | Behaviour | Why |
|--------|-----------|-----|
| `dev` | Last N days (default 3) | Fast iteration; avoids full table scan locally |
| any other | `> MAX(timestamp)` watermark | Correct incremental load for UAT/prod |

```bash
# Override the dev lookback window
dbt run --vars '{"dev_lookback_days": 7}' --select <incremental_model>
```

---

### 4.7 Date Spine Bounds — `dim_dates`, `metricflow_time_spine`

```sql
-- models/utilities/dim_dates.sql
{{ dbt_utils.date_spine(
    datepart   = "day",
    start_date = "cast('" ~ var('date_spine_start') ~ "' as date)",
    end_date   = "cast('" ~ var('date_spine_end')   ~ "' as date)"
) }}
```

Defaults in `dbt_project.yml`: `2020-01-01` → `2026-12-31`.  
Extend the spine without touching model SQL:

```bash
dbt run --vars '{"date_spine_end": "2030-12-31"}' --select dim_dates
```

---

### 4.8 Date Filter for Analytics — `agg_halloween_spending`

```sql
-- models/marts/analytics/agg_halloween_spending.sql
where visit_date >= '{{ var("halloween_analysis_start_date", "2023-01-01") }}'
```

```bash
# Narrow to one year for a faster dev run
dbt run --vars '{"halloween_analysis_start_date": "2024-01-01"}' \
        --select agg_halloween_spending
```

---

### 4.9 Quality Gate Threshold — `agg_happiest_houses`

```sql
-- models/marts/analytics/agg_happiest_houses.sql
where satisfaction_rating >= {{ var('min_satisfaction_rating', 3) }}
```

```bash
# Stricter gate — only 4+ stars
dbt run --vars '{"min_satisfaction_rating": 4}' --select agg_happiest_houses
```

---

### 4.10 Post-Hook Role Grant — `fct_all_ticket_sales`

```sql
{{ config(
    post_hook="GRANT SELECT ON {{ this }} TO ROLE {{ var('bi_role') }}"
) }}
```

`bi_role` has **no in-code default** — it must always be in `dbt_project.yml`
(currently `SYSADMIN`). Omitting it fails loudly rather than silently granting
to the wrong role.

```bash
# Override for a specific BI tool role
dbt run --vars '{"bi_role": "REPORTER"}' --select fct_all_ticket_sales
```

---

---

### 4.11 Pre-hook Session Parameters — `demo_32_pre_hook`

**Problem**: Session parameters like `WEEK_START` and `USE_CACHED_RESULT` default to values that produce wrong weekly buckets and stale cached output. Different machines may have different session defaults.

```sql
{{ config(
    pre_hook=[
        "ALTER SESSION SET TIMEZONE = 'UTC'",
        "ALTER SESSION SET WEEK_START = 1",           -- Monday-anchored ISO weeks
        "ALTER SESSION SET USE_CACHED_RESULT = FALSE"  -- always live for compliance
    ]
) }}
```

Each list element fires as a separate SQL call in order. No multi-statement issue.

**Reusable macro form** (`macros/18_session_settings/set_session_params.sql`):
```sql
pre_hook="{{ set_session_params(timezone='UTC', week_start=1, use_cached_result=false) }}"
```

**Proof the hook works**: the `week_start_day` column always reads `Mon`. The schema test `accepted_values: ['Mon']` enforces this permanently — if the hook is removed, the build fails.

| Session param | Default (Snowflake) | Project value | Why |
|---|---|---|---|
| `TIMEZONE` | account setting | `UTC` | Deterministic timestamps across all environments |
| `WEEK_START` | `0` (Sunday) | `1` (Monday) | ISO 8601; ops schedules run Mon–Sun |
| `USE_CACHED_RESULT` | `TRUE` | `FALSE` | Forces live execution for financial/compliance models |

---

### 4.12 Audit Hook Logging — `demo_33_audit_hooks`

**Problem**: Finance and ops need to know exactly when the LTV dataset was last refreshed and whether the build was within SLA.

Macro pair in `macros/19_audit/run_audit.sql`:

```sql
{{ config(
    pre_hook="{{ log_model_start() }}",
    post_hook="{{ log_model_end() }}"
) }}
```

**Execution flow:**
```
pre_hook  → CREATE SCHEMA/TABLE IF NOT EXISTS SF_TEST.AUDIT.DBT_RUN_LOG
            INSERT  status='running'  started_at=now  run_id=invocation_id
(model builds)
post_hook → UPDATE  status='success'  completed_at=now
                    rows_loaded=COUNT(*)
                    elapsed_seconds=DATEDIFF('second', started_at, now)
```

**Query the audit log:**
```sql
SELECT model_name, status, started_at, rows_loaded, elapsed_seconds
FROM SF_TEST.AUDIT.DBT_RUN_LOG
ORDER BY started_at DESC;
```

Every output row also carries `dbt_run_id = '{{ invocation_id }}'` so a BI consumer can cross-reference any row back to the exact audit log entry that produced it.

---

## 5. `target.*` — Profile Context Variables

Available anywhere in Jinja without explicit declaration.

| Variable | Example value | Common use |
|----------|--------------|------------|
| `target.name` | `'dev'`, `'prod'` | Environment-aware logic (see `incremental_filter`) |
| `target.warehouse` | `'COMPUTE_WH'` | `reset_warehouse()` — restore profile default |
| `target.database` | `'SF_TEST'` | Dynamic schema creation in `on-run-start` |
| `target.schema` | `'PUBLIC'` | Qualify fully-resolved relation names |
| `target.threads` | `8` | Logging / diagnostics |

```sql
-- Real usage in reset_warehouse()
USE WAREHOUSE {{ target.warehouse }};

-- Real usage in on-run-start (dbt_project.yml)
CREATE SCHEMA IF NOT EXISTS {{ target.database }}.INTERMEDIATE
```

---

## 6. Where to Set Variables

| Method | How | When to use |
|--------|-----|-------------|
| `dbt_project.yml` `vars:` block | Persistent project default | Shared business constants (thresholds, date bounds, role names) |
| CLI `--vars '{...}'` | One-off override per run | Ad-hoc analysis, sprint reporting, one-time backfill |
| Developer `~/.dbt/profiles.yml` | Per-engineer default | Local dev only overrides (e.g. `dev_row_limit`) |
| CI/CD job step env vars | GitHub Actions `env:` block | Environment-specific values without touching code |
| `env_var()` in `profiles.yml` | OS environment variable | **Secrets only** — account, password, warehouse name |

---

## 7. Gotchas & Rules

| Rule | Reason |
|------|--------|
| Always provide a `default` in `var('x', default)` | Missing default raises a hard compile error if the var is absent from CLI and `dbt_project.yml` — except when you *want* that failure (e.g. `bi_role`) |
| Never set `dev_row_limit` in `dbt_project.yml` | It would silently cap prod queries |
| Never put secrets in `var()` | Secrets appear in `target/compiled/` SQL files and query logs — use `env_var()` in `profiles.yml` only |
| Stamp active var values onto output rows | Allows BI tools to build dynamic labels without hardcoding thresholds in reports |
| `feature_flag` defaults to `false` | New flags are safe by default — must be explicitly turned on |
| `reset_warehouse()` always uses `target.warehouse` | Ensures the session warehouse returns to the profile default regardless of which model ran before |

---

## 8. Quick Reference — All CLI Overrides

```bash
# Rolling window
dbt run --vars '{"lookback_days": 30}'   --select demo_28_var_date_window

# Spend tiers
dbt run --vars '{"spend_tier_high": 400, "spend_tier_mid": 150}' \
        --select demo_29_var_spend_tiers

# Warehouse for heavy model
dbt run --vars '{"heavy_model_warehouse": "DBT_WH_LARGE"}' \
        --select demo_30_warehouse_switch

# Dev row cap
dbt run --vars '{"dev_row_limit": 500}'  --select demo_31_var_dev_limit

# Feature flag on
dbt run --vars '{"use_new_pricing_model": true}' --select demo_10_feature_flag

# Incremental dev window
dbt run --vars '{"dev_lookback_days": 7}' --select <incremental_model>

# Date spine range
dbt run --vars '{"date_spine_end": "2030-12-31"}' --select dim_dates

# Halloween analysis window
dbt run --vars '{"halloween_analysis_start_date": "2024-01-01"}' \
        --select agg_halloween_spending

# Satisfaction gate
dbt run --vars '{"min_satisfaction_rating": 4}' --select agg_happiest_houses

# BI role grant
dbt run --vars '{"bi_role": "REPORTER"}' --select fct_all_ticket_sales
```
