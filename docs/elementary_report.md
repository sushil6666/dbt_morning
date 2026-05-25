# Elementary Report — Setup & Run Guide

> **Audience:** Analytics engineers working on the `dbt_practice` Theme Park project.  
> **Engine:** dbt-fusion 2.x · Elementary 0.23.1 · Snowflake  
> **Last updated:** 2026-05-02

---

## Table of Contents

1. [What is Elementary?](#what-is-elementary)
2. [One-Time Setup](#one-time-setup)
3. [Full Workflow — Build & Report](#full-workflow--build--report)
4. [Step-by-Step Commands](#step-by-step-commands)
5. [Stopping the Server](#stopping-the-server)
6. [What You See in the Report](#what-you-see-in-the-report)
7. [Troubleshooting](#troubleshooting)

---

## What is Elementary?

Elementary is an open-source data observability tool for dbt. It captures every model run, test result, and unit test outcome into Snowflake tables automatically via `on-run-end` hooks, then generates a local HTML report you can browse.

**Tables it writes to:**

| Table | Contents |
|---|---|
| `SF_TEST.elementary.dbt_run_results` | Every model, test, and unit test run with status and timing |
| `SF_TEST.elementary.elementary_test_results` | Enriched test results with metadata |
| `SF_TEST.elementary.dbt_models` | Model catalog and lineage |

---

## One-Time Setup

These steps only need to be done once per environment.

### 1. Install Elementary CLI

```bash
pip install elementary-data
```

Verify:
```bash
edr --version
```

### 2. Add the `elementary` profile to `~/.dbt/profiles.yml`

Elementary's CLI (`edr`) requires its own profile named `elementary`. Add the following block to `~/.dbt/profiles.yml` — use the same Snowflake credentials as `dbt_batch`:

```yaml
elementary:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: CUPODEE-VQB60821
      user: SUSHIL
      password: <your_password>
      role: ACCOUNTADMIN
      database: SF_TEST
      warehouse: DBT_WH
      schema: elementary
      threads: 6
```

> **Why a separate profile?** `edr` runs its own internal dbt project to query Elementary's tables. It looks specifically for a profile named `elementary` pointing at the `elementary` schema.

### 3. Build Elementary models into Snowflake

This creates the Elementary tracking tables (`dbt_run_results`, `elementary_test_results`, etc.) in `SF_TEST.elementary`:

```bash
dbt run --select elementary
```

### 4. Create the INTERMEDIATE schema (unit test requirement)

All intermediate models are ephemeral and never create their own schema. Run once per environment so unit tests can execute:

```bash
dbt run-operation create_schema --args '{"schema_name": "INTERMEDIATE"}'
```

### 5. Pin Elementary to the correct schema in `dbt_project.yml`

Without this, dbt-fusion defaults Elementary model hooks to write into the target schema (`DBT_BATCH_DEV`) instead of `elementary`. Ensure this block exists in `dbt_project.yml`:

```yaml
models:
  elementary:
    +schema: elementary
```

---

## Full Workflow — Build & Report

Run these commands in order each time you want a fresh report:

```bash
# 1. Build all models, run all tests (including unit tests)
dbt build

# 2. Generate the Elementary HTML report
edr report \
  --profiles-dir ~/.dbt \
  --profile-target dev \
  --project-dir /home/insightstack/DBT-SF-code \
  --open-browser false

# 3. Start a local HTTP server
fuser -k 8080/tcp 2>/dev/null
cd /home/insightstack/DBT-SF-code/edr_target && nohup python3 -m http.server 8080 > /tmp/http_server.log 2>&1 &

# 4. Open in browser (WSL2 → Windows browser)
powershell.exe -c "Start-Process 'http://localhost:8080/elementary_report.html'"
```

**Report is live at:** http://localhost:8080/elementary_report.html

---

## Step-by-Step Commands

### Step 1 — `dbt build`

Builds all models, seeds, snapshots, and runs all tests (generic, singular, and unit tests) in dependency order.

```bash
dbt build
```

Expected output:
```
Summary: 525 total | 481 success | 22 error | ...
```

> The 22 errors are **pre-existing known issues**:
> - Temp table tests (`demo_16`) — temp tables drop after the session, so data tests on them always fail
> - Hybrid table (`demo_17`) — not available on Snowflake trial accounts

### Step 2 — Generate the report

```bash
edr report \
  --profiles-dir ~/.dbt \
  --profile-target dev \
  --project-dir /home/insightstack/DBT-SF-code \
  --open-browser false
```

This reads from `SF_TEST.elementary.*` tables and produces:
```
edr_target/elementary_report.html   (6.8 MB static HTML file)
```

### Step 3 — Start the HTTP server

```bash
fuser -k 8080/tcp 2>/dev/null
cd /home/insightstack/DBT-SF-code/edr_target
nohup python3 -m http.server 8080 > /tmp/http_server.log 2>&1 &
```

Verify the server is up:
```bash
curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:8080/elementary_report.html
# Expected: HTTP 200
```

### Step 4 — Open in browser

**WSL2 (opens in Windows default browser):**
```bash
powershell.exe -c "Start-Process 'http://localhost:8080/elementary_report.html'"
```

**Linux desktop:**
```bash
xdg-open http://localhost:8080/elementary_report.html
```

**Mac:**
```bash
open http://localhost:8080/elementary_report.html
```

Or navigate manually to: **http://localhost:8080/elementary_report.html**

---

## Stopping the Server

```bash
fuser -k 8080/tcp
```

---

## What You See in the Report

| Section | What it shows |
|---|---|
| **Test Runs** | All test executions — generic, singular, and unit tests — with pass/fail status, model name, and execution time |
| **Model Runs** | Every model build with run time and status across invocations |
| **Test Coverage** | Which models have tests vs. which have none |
| **Lineage** | DAG view of model dependencies |

### Finding your unit tests in the report

In the **Test Runs** section, filter by `resource_type = unit_test` or search by test name. Your 10 unit tests appear as:

| Test Name | Model |
|---|---|
| `test_spending_tier_boundaries` | `demo_26_ephemeral_base` |
| `test_revenue_category_ilike_mapping` | `demo_26_ephemeral_base` |
| `test_daily_revenue_ticket_only_date` | `int_daily_revenue` |
| `test_daily_revenue_sales_only_date` | `int_daily_revenue` |
| `test_daily_revenue_category_splitting` | `int_daily_revenue` |
| `test_ride_metrics_no_reviews` | `int_ride_metrics` |
| `test_ride_metrics_positive_review_pct` | `int_ride_metrics` |
| `test_customer_visit_no_inpark_spend` | `int_customer_visits` |
| `test_customer_visit_with_spend_and_feedback` | `int_customer_visits` |
| `test_is_discounted_flag` | `stg_sales__tickets` |

You can also query the results directly in Snowflake:

```sql
SELECT
    name,
    status,
    resource_type,
    ROUND(execution_time, 2) AS exec_sec,
    generated_at
FROM SF_TEST.elementary.dbt_run_results
WHERE resource_type = 'unit_test'
ORDER BY generated_at DESC;
```

---

## Troubleshooting

### `Could not find profile named 'elementary'`

The `elementary` profile is missing from `~/.dbt/profiles.yml`. Add it as shown in [One-Time Setup → Step 2](#2-add-the-elementary-profile-to-dbtprofilesyml).

### Unit tests not appearing in report

Elementary models were built into the wrong schema. Run:
```bash
dbt run --select elementary
dbt test --select test_type:unit
```
Then regenerate the report.

### `Schema 'SF_TEST.INTERMEDIATE' does not exist`

Run the one-time schema creation:
```bash
dbt run-operation create_schema --args '{"schema_name": "INTERMEDIATE"}'
```

### Port 8080 already in use

```bash
fuser -k 8080/tcp
```
Then restart the server (Step 3).

### Report looks stale / data is old

Always run `dbt build` **before** `edr report` — Elementary captures results during the build via `on-run-end` hooks, not during report generation.
