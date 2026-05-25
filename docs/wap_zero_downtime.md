# Write-Audit-Publish (WAP) & Zero-Downtime Swap

> **Target warehouse:** Snowflake  
> **dbt runtime:** dbt-fusion 2.0 (preview)  
> **Profile:** `dbt_batch`  
> **Macros:** `macros/07_zero_downtime/`  
> **Demo model:** `models/macro_demos/demo_07_zero_downtime.sql`

---

## Table of Contents

1. [What is WAP?](#1-what-is-wap)
2. [Why WAP?](#2-why-wap)
3. [Pattern A — Schema-Level WAP (recommended)](#3-pattern-a--schema-level-wap-recommended)
4. [Pattern B — Table-Level Swap (per-model)](#4-pattern-b--table-level-swap-per-model)
5. [Macro Reference](#5-macro-reference)
6. [Profile Targets](#6-profile-targets)
7. [CI/CD Pipeline Integration](#7-cicd-pipeline-integration)
8. [Rollback Strategy](#8-rollback-strategy)
9. [Pattern Comparison](#9-pattern-comparison)
10. [When to Use Which Pattern](#10-when-to-use-which-pattern)

---

## 1. What is WAP?

**Write-Audit-Publish** is a data deployment pattern that completely separates the act of building data from the act of exposing it to consumers. Instead of writing directly into production, you:

```
WRITE  →  AUDIT  →  PUBLISH
  │           │          │
  ▼           ▼          ▼
Build into  Run all   Swap candidate
 candidate   tests      into prod
  schema    against   (instantaneous)
           candidate
```

The key insight: **prod is never touched until every test has passed**. If the audit fails, prod stays on the last known-good version — your BI dashboards and downstream consumers see nothing wrong.

---

## 2. Why WAP?

| Problem without WAP | How WAP solves it |
|---|---|
| A broken model replaces prod before tests run | Prod is only replaced after all tests pass |
| BI dashboards show partial/in-progress data during a long build | Swap is instantaneous — dashboards flip atomically |
| A failed run leaves prod in a corrupt state | Candidate is discarded; prod is unchanged |
| No way to test prod-equivalent data before it goes live | Candidate is a full prod-equivalent environment |

---

## 3. Pattern A — Schema-Level WAP (recommended)

This is the pattern illustrated in the diagram: an entire **Candidate** environment is built, tested, and then swapped wholesale into **Prod**.

```
┌─────────────────────────────────────────────────┐
│  PROD  (DBT_BATCH_PROD)                         │
│                                    my_table ◄─┐ │
└────────────────────────────────────────────────┼─┘
                                  SWAP WITH      │
┌─────────────────────────────────────────────────┼─┐
│  CANDIDATE  (DBT_BATCH_CANDIDATE)               │ │
│                                                 │ │
│   Build and test ──────────────► my_table ──────┘ │
└───────────────────────────────────────────────────┘
```

### Step 1 — Write

Build the entire project into the candidate schema. Nothing in prod is touched.

```bash
dbt run --target candidate
```

All models land in `SF_TEST.DBT_BATCH_CANDIDATE.*`

### Step 2 — Audit

Run every test against the candidate schema. If any test fails, stop — prod is unaffected.

```bash
dbt test --target candidate
```

### Step 3 — Publish

Promote candidate into prod via schema renames. Three Snowflake `RENAME SCHEMA` operations — all metadata-only, no data is copied or moved.

```bash
dbt run-operation swap_schemas \
  --args '{
    "candidate_schema": "DBT_BATCH_CANDIDATE",
    "prod_schema":      "DBT_BATCH_PROD"
  }' \
  --target prod
```

#### What `swap_schemas` does internally

```
1. DROP SCHEMA   SF_TEST.DBT_BATCH_PROD_BACKUP        ← clear previous backup
2. RENAME SCHEMA SF_TEST.DBT_BATCH_PROD      → SF_TEST.DBT_BATCH_PROD_BACKUP
3. RENAME SCHEMA SF_TEST.DBT_BATCH_CANDIDATE → SF_TEST.DBT_BATCH_PROD   ← publish
4. DROP SCHEMA   SF_TEST.DBT_BATCH_PROD_BACKUP        ← clean up (unless keep_backup=true)
```

Steps 2 and 3 are the "swap" — they are metadata renames in Snowflake's catalog. The window between them (where prod is momentarily renamed to backup) is sub-millisecond. BI tools that query `DBT_BATCH_PROD` tables will see an uninterrupted, consistent view throughout.

---

## 4. Pattern B — Table-Level Swap (per-model)

Use this when you want the zero-downtime guarantee for a **single high-value table** without switching the whole environment. This uses the `pre_swap_clone` / `post_swap_table` macros.

### How it works

```
pre_hook  → CLONE current prod table to {model}_backup   (safety net)
            dbt builds {model}_staging                    (the new version)
post_hook → ALTER TABLE {model}_staging SWAP WITH {model} (atomic swap)
            DROP TABLE  {model}_backup                    (clean up)
```

### Model config

```sql
{{ config(
    materialized = 'table',
    pre_hook     = "{{ pre_swap_clone() }}",
    post_hook    = "{{ post_swap_table(this.schema ~ '.' ~ this.name ~ '_staging') }}"
) }}
```

> **First-run caveat:** `pre_swap_clone()` clones the existing prod table — the table must already exist for the clone to succeed. On a brand-new model's first run, omit the hooks and add them from the second run onwards.

### What the macros generate

**pre_hook (before the model builds):**
```sql
CREATE OR REPLACE TABLE DBT_BATCH_PROD.my_model_backup
CLONE DBT_BATCH_PROD.my_model
```

**post_hook (after the model builds successfully):**
```sql
ALTER TABLE DBT_BATCH_PROD.my_model_staging SWAP WITH DBT_BATCH_PROD.my_model;
DROP TABLE IF EXISTS DBT_BATCH_PROD.my_model_staging_backup
```

The `SWAP` statement is atomic in Snowflake — the table name `my_model` instantly points to the new data, with no gap visible to any active query.

---

## 5. Macro Reference

### `swap_schemas` — `macros/07_zero_downtime/swap_schemas.sql`

Schema-level WAP publish step.

| Argument | Type | Default | Description |
|---|---|---|---|
| `candidate_schema` | string | `target.schema` | Schema to promote into prod |
| `prod_schema` | string | **required** | Schema to replace |
| `database` | string | `target.database` | Snowflake database containing both schemas |
| `keep_backup` | boolean | `false` | When `true`, retains `{prod}_BACKUP` after the swap for manual rollback |

```bash
# Minimal call
dbt run-operation swap_schemas \
  --args '{"candidate_schema": "DBT_BATCH_CANDIDATE", "prod_schema": "DBT_BATCH_PROD"}' \
  --target prod

# Keep backup for rollback window
dbt run-operation swap_schemas \
  --args '{
    "candidate_schema": "DBT_BATCH_CANDIDATE",
    "prod_schema":      "DBT_BATCH_PROD",
    "keep_backup":      true
  }' \
  --target prod
```

---

### `pre_swap_clone` — `macros/07_zero_downtime/zero_downtime_swap.sql`

Table-level safety clone. Called as a `pre_hook` on the model being rebuilt.

```jinja
{{ pre_swap_clone() }}
```

Generates:
```sql
CREATE OR REPLACE TABLE {schema}.{model}_backup
CLONE {schema}.{model}
```

---

### `post_swap_table` — `macros/07_zero_downtime/zero_downtime_swap.sql`

Table-level atomic swap. Called as a `post_hook` after the model builds successfully.

```jinja
{{ post_swap_table(staging_table) }}
```

| Argument | Description |
|---|---|
| `staging_table` | Fully-qualified name of the newly built staging table |

Generates:
```sql
ALTER TABLE {staging_table} SWAP WITH {schema}.{model};
DROP TABLE IF EXISTS {staging_table}_backup
```

---

## 6. Profile Targets

All four targets in `~/.dbt/profiles.yml` under the `dbt_batch` profile:

| Target | Schema | Purpose |
|---|---|---|
| `dev` | `DBT_BATCH_DEV` | Individual developer iteration |
| `uat` | `DBT_BATCH_UAT` | Pre-production validation |
| `candidate` | `DBT_BATCH_CANDIDATE` | WAP write + audit environment |
| `prod` | `DBT_BATCH_PROD` | Live production — only touched by `swap_schemas` |

Run against a specific target with `--target <name>`:
```bash
dbt run  --target candidate
dbt test --target candidate
dbt run-operation swap_schemas --args '{...}' --target prod
```

---

## 7. CI/CD Pipeline Integration

A typical GitHub Actions / dbt Cloud job sequence for WAP:

```
Job 1 — Build candidate
  dbt deps
  dbt seed   --target candidate
  dbt run    --target candidate

Job 2 — Audit candidate  (runs only if Job 1 succeeds)
  dbt test   --target candidate
  dbt source freshness --target candidate

Job 3 — Publish to prod  (runs only if Job 2 succeeds)
  dbt run-operation swap_schemas \
    --args '{"candidate_schema": "DBT_BATCH_CANDIDATE", "prod_schema": "DBT_BATCH_PROD"}' \
    --target prod
```

**On failure:**
- Job 1 fails → candidate is incomplete, Job 2 never runs, prod is untouched
- Job 2 fails → tests failed, Job 3 never runs, prod is untouched
- Job 3 fails → candidate exists but is not in prod; investigate and re-run Job 3

---

## 8. Rollback Strategy

### Schema-level rollback

If an issue is discovered after the swap, re-run `swap_schemas` in reverse — or, if `keep_backup=true` was used, the backup schema is ready immediately:

```bash
# Rollback: swap prod back to the previous version (stored in BACKUP)
dbt run-operation swap_schemas \
  --args '{
    "candidate_schema": "DBT_BATCH_PROD_BACKUP",
    "prod_schema":      "DBT_BATCH_PROD"
  }' \
  --target prod
```

### Table-level rollback

The `pre_swap_clone` pre-hook creates `{model}_backup` before every build. To roll back manually:

```sql
ALTER TABLE DBT_BATCH_PROD.my_model_backup SWAP WITH DBT_BATCH_PROD.my_model;
```

---

## 9. Pattern Comparison

| | Schema-Level WAP | Table-Level Swap |
|---|---|---|
| **Scope** | Entire project (all schemas) | Single model |
| **Atomicity** | Near-atomic (two fast renames) | Fully atomic (`ALTER TABLE SWAP`) |
| **BI downtime** | Sub-millisecond | Zero |
| **Requires separate environment** | Yes (`candidate` target) | No |
| **First-run safe** | Yes — candidate schema is fresh | No — prod table must exist first |
| **Best for** | Full prod deployments via CI/CD | Single critical mart tables |
| **Macros** | `swap_schemas` | `pre_swap_clone` + `post_swap_table` |

---

## 10. When to Use Which Pattern

**Use Schema-Level WAP when:**
- You want a true blue-green deployment for the whole project
- You're running a scheduled CI/CD pipeline (not interactive)
- You need all tables to be consistent with each other post-deploy (referential integrity across tables)
- You want prod to be completely isolated from any in-progress build

**Use Table-Level Swap when:**
- Only one or two high-value mart tables need zero-downtime protection
- You can't maintain a full candidate environment (cost or tooling constraints)
- The table already exists in prod (first-run caveat above)
- You're doing a one-off rebuild outside the normal CI/CD pipeline
