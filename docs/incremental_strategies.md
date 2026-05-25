# dbt Incremental Strategies — Snowflake Reference

> **Audience:** Analytics engineers building production dbt models on Snowflake.  
> **Engine:** dbt-core 1.7+ / dbt-fusion 2.x · Snowflake adapter  
> **Last updated:** 2026-04-25

---

## Table of Contents

1. [Why Incremental Matters](#why-incremental-matters)
2. [Strategy: merge](#-strategy-merge)
3. [Strategy: append](#-strategy-append)
4. [Strategy: delete+insert](#-strategy-deleteinsert)
5. [Strategy: insert_overwrite](#-strategy-insert_overwrite)
6. [Strategy: microbatch](#-strategy-microbatch)
7. [Strategy Comparison Matrix](#strategy-comparison-matrix)
8. [Snowflake-Specific Notes](#snowflake-specific-notes)
9. [Watermark Guidance](#watermark-guidance)
10. [Common Mistakes](#common-mistakes)

---

## Why Incremental Matters

Full-refresh models re-scan and rewrite every row on every run. For tables with tens of millions of rows, that is a Snowflake credit burn with no benefit. Incremental models read only the rows that changed since the last run and merge them into the target — trading model complexity for dramatically lower cost and faster run times.

Choose a strategy based on two axes:

| Axis | Question |
|------|----------|
| **Mutability** | Can existing rows change, or are they append-only? |
| **Granularity** | Do you filter by timestamp/ID or by whole date partitions? |

---

## 🔹 Strategy: merge

### 1. Description

`merge` is the default Snowflake incremental strategy. dbt issues a single `MERGE INTO` statement that **inserts new rows and updates existing ones** in one atomic operation.

Execution flow:
1. Compile the model SQL into a CTE or subquery (the *source*).
2. Apply the `is_incremental()` filter so the source only contains recent rows.
3. Issue `MERGE INTO <target> USING <source> ON <unique_key> WHEN MATCHED THEN UPDATE ... WHEN NOT MATCHED THEN INSERT ...`.

### 2. Configuration

```sql
{{ config(
    materialized          = 'incremental',
    incremental_strategy  = 'merge',
    unique_key            = 'order_id',
    merge_update_columns  = ['status', 'updated_at', 'total_amount'],
    on_schema_change      = 'sync_all_columns',
    cluster_by            = ['order_date']
) }}
```

| Option | Required | Notes |
|--------|----------|-------|
| `unique_key` | Yes | Single column or list `['col_a', 'col_b']` for composite key |
| `merge_update_columns` | No | Limits which columns are updated on MATCH; omit to update all |
| `on_schema_change` | No | `ignore` (default) · `sync_all_columns` · `fail` · `append_new_columns` |

### 3. Sample Data

**Incoming batch (source)**

| order_id | customer_id | status   | total_amount | updated_at          |
|----------|-------------|----------|-------------|---------------------|
| 1001     | 42          | shipped  | 150.00      | 2024-06-10 08:00:00 |
| 1002     | 17          | pending  | 75.50       | 2024-06-10 09:15:00 |
| 1003     | 55          | new      | 210.00      | 2024-06-10 10:00:00 |

**Existing target**

| order_id | customer_id | status  | total_amount | updated_at          |
|----------|-------------|---------|-------------|---------------------|
| 1001     | 42          | pending | 150.00      | 2024-06-09 14:00:00 |
| 1002     | 17          | pending | 75.50       | 2024-06-09 16:00:00 |

**After merge**

| order_id | customer_id | status  | total_amount | updated_at          |
|----------|-------------|---------|-------------|---------------------|
| 1001     | 42          | shipped | 150.00      | 2024-06-10 08:00:00 |  ← updated
| 1002     | 17          | pending | 75.50       | 2024-06-09 16:00:00 |  ← unchanged (same updated_at)
| 1003     | 55          | new     | 210.00      | 2024-06-10 10:00:00 |  ← inserted

### 4. Sample Model

```sql
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    unique_key           = 'order_id',
    merge_update_columns = ['status', 'updated_at', 'total_amount'],
    cluster_by           = ['order_date']
) }}

with source as (
    select
        order_id,
        customer_id,
        order_date,
        status,
        total_amount,
        updated_at
    from {{ ref('stg_orders') }}

    {% if is_incremental() %}
        where updated_at > (select max(updated_at) from {{ this }})
    {% endif %}
)

select * from source
```

> **Watermark column:** `updated_at` — the most recent value in the target table is used as the lower bound.  
> Always use the source `updated_at`, not a `current_timestamp()` call.

### 5. Key Behaviors

| Behavior | Detail |
|----------|--------|
| **Insert** | Rows with no matching `unique_key` in the target are inserted |
| **Update** | Rows with a matching key overwrite target columns (all or only `merge_update_columns`) |
| **Delete** | No deletes — rows disappear from source but remain in target |
| **Late data** | Handled naturally; any row with `updated_at > max(target.updated_at)` is processed |
| **Performance** | Single DML statement; Snowflake optimizes via micro-partition pruning when clustered |

### 6. Verification Query

```sql
-- Confirm no duplicate unique keys after merge
select order_id, count(*) as cnt
from {{ this }}
group by 1
having cnt > 1;

-- Confirm updated rows have the expected status
select order_id, status, updated_at
from {{ this }}
where order_id in (1001, 1003)
order by order_id;
```

### 7. When to Use

- Order or transaction tables where rows mutate (`status`, `amount`) after creation.
- SCD Type 1 (overwrite-in-place) dimension updates.
- Any source that guarantees an `updated_at` watermark column.
- Tables with moderate fan-out (millions, not billions of rows per run).

### 8. Best Practices

- **Watermark column must be indexed on the source system.** A full scan on `updated_at` upstream defeats the purpose.
- **Use `merge_update_columns`** to protect audit columns (`created_at`, `inserted_at`) from being overwritten on every merge.
- **Cluster on `order_date` or `updated_at`** so Snowflake prunes micro-partitions on both the `is_incremental()` filter and join lookups.
- **Avoid composite unique keys wider than 3 columns.** Merge performance degrades as the join predicate grows.
- **Pitfall:** Using `>= max(updated_at)` instead of `> max(updated_at)` re-processes the boundary row every run. Use strict `>`.

---

## 🔹 Strategy: append

### 1. Description

`append` inserts every row produced by the model SQL into the target table **without checking for duplicates**. No MERGE, no DELETE — pure `INSERT INTO ... SELECT`.

Execution flow:
1. Compile model SQL with `is_incremental()` filter active.
2. Issue `INSERT INTO <target> SELECT ... FROM <compiled_sql>`.

### 2. Configuration

```sql
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'append'
) }}
```

| Option | Required | Notes |
|--------|----------|-------|
| `unique_key` | No | Ignored entirely — no deduplication |
| `on_schema_change` | No | `ignore` · `append_new_columns` · `fail` |

### 3. Sample Data

**Incoming batch**

| event_id | user_id | event_type | occurred_at         |
|----------|---------|-----------|---------------------|
| e-901    | 5       | click     | 2024-06-10 11:00:00 |
| e-902    | 12      | pageview  | 2024-06-10 11:01:00 |

**Existing target**

| event_id | user_id | event_type | occurred_at         |
|----------|---------|-----------|---------------------|
| e-800    | 3       | purchase  | 2024-06-09 22:00:00 |

**After append**

| event_id | user_id | event_type | occurred_at         |
|----------|---------|-----------|---------------------|
| e-800    | 3       | purchase  | 2024-06-09 22:00:00 |
| e-901    | 5       | click     | 2024-06-10 11:00:00 |  ← inserted
| e-902    | 12      | pageview  | 2024-06-10 11:01:00 |  ← inserted

### 4. Sample Model

```sql
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'append'
) }}

with events as (
    select
        event_id,
        user_id,
        event_type,
        occurred_at,
        session_id,
        page_url
    from {{ ref('stg_events') }}

    {% if is_incremental() %}
        where occurred_at > (select coalesce(max(occurred_at), '1970-01-01') from {{ this }})
    {% endif %}
)

select * from events
```

> **Immutable sources only.** If your source ever corrects or retracts past events, this model will accumulate stale rows silently.

### 5. Key Behaviors

| Behavior | Detail |
|----------|--------|
| **Insert** | All incoming rows are inserted unconditionally |
| **Update** | Not supported — existing rows are never touched |
| **Delete** | Not supported — no rows are removed |
| **Duplicates** | Will accumulate if the same event is processed twice (e.g., pipeline replay) |
| **Performance** | Fastest strategy — single INSERT, zero lookups, maximum write throughput |

### 6. Verification Query

```sql
-- Confirm row count growth matches expected batch size
select date(occurred_at) as event_date, count(*) as row_count
from {{ this }}
group by 1
order by 1 desc
limit 7;

-- Detect accidental duplicates
select event_id, count(*) as cnt
from {{ this }}
group by 1
having cnt > 1
limit 20;
```

### 7. When to Use

- Immutable event streams: clickstream, server logs, IoT telemetry.
- Audit / append-only ledgers where history must never be rewritten.
- High-volume data where merge overhead is unacceptable and data is guaranteed unique at the source.

### 8. Best Practices

- **Gate your pipeline upstream** to prevent replays that would create duplicates.
- **Add a `_loaded_at` column** (`current_timestamp()`) so you can detect and filter accidental re-ingestion.
- **Cluster on `occurred_at`** to ensure new rows land in a small number of micro-partitions and don't scatter across the table.
- **Pitfall:** Using `append` for mutable data (orders, users) means your target diverges from the source over time. Use `merge` instead.
- **Pitfall:** Omitting `is_incremental()` filter means the model re-scans the full source on every run — the same cost as a full refresh.

---

## 🔹 Strategy: delete+insert

### 1. Description

`delete+insert` replaces a **partition** of the target table in two steps: first delete all rows where the partition column matches the incoming batch window, then insert all rows for that window. This is the canonical strategy for **date-partitioned fact tables**.

Execution flow:
1. Determine the partition values from the incoming source (e.g., distinct `event_date` values).
2. `DELETE FROM <target> WHERE <partition_col> IN (<values from source>)`.
3. `INSERT INTO <target> SELECT ... FROM <compiled_sql>`.

Both steps run inside the same transaction.

### 2. Configuration

```sql
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'delete+insert',
    unique_key           = 'event_date',
    on_schema_change     = 'sync_all_columns'
) }}
```

| Option | Required | Notes |
|--------|----------|-------|
| `unique_key` | Yes | The **partition column** — all rows matching this value are deleted and rewritten |
| `partition_by` | No | Not native Snowflake DDL; use `cluster_by` instead |

> `unique_key` here means "the column(s) that define a replaceable partition", not a row-level primary key.

### 3. Sample Data

**Incoming batch (restatement of 2024-06-09 + new 2024-06-10)**

| sale_id | sale_date  | revenue |
|---------|-----------|---------|
| s-200   | 2024-06-09 | 500.00  |  ← corrected row
| s-300   | 2024-06-10 | 800.00  |  ← new row

**Existing target**

| sale_id | sale_date  | revenue |
|---------|-----------|---------|
| s-200   | 2024-06-09 | 450.00  |  ← stale
| s-100   | 2024-06-08 | 300.00  |

**After delete+insert**

| sale_id | sale_date  | revenue |
|---------|-----------|---------|
| s-100   | 2024-06-08 | 300.00  |  ← untouched
| s-200   | 2024-06-09 | 500.00  |  ← replaced
| s-300   | 2024-06-10 | 800.00  |  ← inserted

### 4. Sample Model

```sql
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'delete+insert',
    unique_key           = 'sale_date',
    cluster_by           = ['sale_date']
) }}

with sales as (
    select
        sale_id,
        customer_id,
        sale_date,
        product_id,
        quantity,
        unit_price,
        quantity * unit_price as revenue
    from {{ ref('stg_sales') }}

    {% if is_incremental() %}
        -- Reload the last 3 days to capture late-arriving corrections
        where sale_date >= (select dateadd('day', -3, max(sale_date)) from {{ this }})
    {% endif %}
)

select * from sales
```

> **Look-back window:** Loading `max(sale_date) - 3 days` absorbs late arrivals. Tune the window to your SLA.

### 5. Key Behaviors

| Behavior | Detail |
|----------|--------|
| **Insert** | All rows for the processed partition window are inserted |
| **Update** | Achieved implicitly — the old partition is deleted, new values are inserted |
| **Delete** | Rows vanish when the entire partition is wiped, even if not in the new source batch |
| **Atomicity** | DELETE + INSERT run in a transaction; partial failure rolls back |
| **Performance** | Very fast for wide date slices; slower than append for tiny increments |

### 6. Verification Query

```sql
-- Row count by date (expect no gaps in the reloaded window)
select sale_date, count(*) as row_count, sum(revenue) as total_revenue
from {{ this }}
where sale_date >= dateadd('day', -7, current_date())
group by 1
order by 1;

-- Confirm corrected revenue landed
select sale_id, sale_date, revenue
from {{ this }}
where sale_id = 's-200';
```

### 7. When to Use

- Daily fact tables where upstream systems issue corrected files for T-1 or T-2.
- ETL pipelines where the unit of work is a date partition, not a row.
- Any scenario where "replace the last N days" is the right semantic.

### 8. Best Practices

- **Cluster on the partition column** (`cluster_by = ['sale_date']`) so the DELETE scans minimal micro-partitions.
- **Use a look-back window** (`max(date) - N days`) rather than `max(date)` alone to absorb late data.
- **Never use a high-cardinality column** (e.g., `sale_id`) as the `unique_key` — it would delete one row at a time, which is as expensive as a full merge.
- **Pitfall:** Using `delete+insert` without a `cluster_by` causes Snowflake to scan the entire table on every DELETE, erasing the performance benefit.
- **Pitfall:** Setting too narrow a look-back window silently leaves stale corrections in the table.

---

## 🔹 Strategy: insert_overwrite

### 1. Description

`insert_overwrite` overwrites **entire partitions** of the target table using Snowflake's `INSERT OVERWRITE INTO` syntax. It is conceptually similar to `delete+insert` but operates at the storage level without an explicit DELETE step, which can be faster for large partitions.

> **Important:** Snowflake does not have BigQuery-style named partitions. The Snowflake dbt adapter implements `insert_overwrite` by using `INSERT OVERWRITE INTO <target> SELECT ... FROM <source>` — which replaces **all rows** whose partition key matches the source's range. Clustering is what makes partition pruning work.

Execution flow:
1. Compile model SQL with `is_incremental()` filter.
2. Issue `INSERT OVERWRITE INTO <target> SELECT ... FROM <compiled_sql>`.

### 2. Configuration

```sql
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'insert_overwrite',
    cluster_by           = ['event_month']
) }}
```

| Option | Required | Notes |
|--------|----------|-------|
| `unique_key` | No | Not used for matching; the overwrite is partition-scoped |
| `cluster_by` | Strongly recommended | Without clustering, `INSERT OVERWRITE` replaces the entire table |

### 3. Sample Data

**Incoming batch (June 2024 metrics, fully recalculated)**

| metric_month | product_id | total_units | total_revenue |
|-------------|-----------|-------------|--------------|
| 2024-06     | P-10      | 1200        | 36000.00     |
| 2024-06     | P-11      | 800         | 19200.00     |

**Existing target**

| metric_month | product_id | total_units | total_revenue |
|-------------|-----------|-------------|--------------|
| 2024-05     | P-10      | 1100        | 33000.00     |
| 2024-06     | P-10      | 1150        | 34500.00     |  ← stale

**After insert_overwrite**

| metric_month | product_id | total_units | total_revenue |
|-------------|-----------|-------------|--------------|
| 2024-05     | P-10      | 1100        | 33000.00     |  ← untouched
| 2024-06     | P-10      | 1200        | 36000.00     |  ← replaced
| 2024-06     | P-11      | 800         | 19200.00     |  ← inserted

### 4. Sample Model

```sql
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'insert_overwrite',
    cluster_by           = ['metric_month']
) }}

with monthly_metrics as (
    select
        date_trunc('month', sale_date)                   as metric_month,
        product_id,
        sum(quantity)                                    as total_units,
        sum(quantity * unit_price)                       as total_revenue,
        count(distinct customer_id)                      as unique_customers
    from {{ ref('fct_sales') }}

    {% if is_incremental() %}
        -- Recompute the current month and the previous month (for corrections)
        where sale_date >= date_trunc('month', dateadd('month', -1, current_date()))
    {% endif %}

    group by 1, 2
)

select * from monthly_metrics
```

### 5. Key Behaviors

| Behavior | Detail |
|----------|--------|
| **Insert** | New partition values are written |
| **Update** | Entire partition is replaced atomically |
| **Delete** | Rows not in the new batch disappear from the overwritten partition |
| **Without clustering** | All rows in the table are replaced — equivalent to full refresh |
| **Performance** | Fastest for aggregate/rollup tables with coarse partition granularity |

### 6. Verification Query

```sql
-- Confirm only the target months were overwritten
select metric_month, count(*) as products, sum(total_revenue) as revenue
from {{ this }}
group by 1
order by 1 desc
limit 6;

-- Ensure prior months were not touched
select metric_month, total_units, total_revenue
from {{ this }}
where metric_month = '2024-05-01'
  and product_id = 'P-10';
```

### 7. When to Use

- Monthly/weekly aggregate rollup tables that are fully recomputed from source data.
- Reporting layers where an entire time window is recalculated on each pipeline run.
- Scenarios where `delete+insert` produces too many small transactions.

### 8. Best Practices

- **Always cluster** the table on the partition column. Without it, `INSERT OVERWRITE` replaces everything.
- **Compute coarse granularities** (month, week) rather than fine (day, hour) — the strategy shines when one partition contains many rows.
- **Pitfall:** Confusing `insert_overwrite` with BigQuery's `WRITE_TRUNCATE` partition mode. In Snowflake, it is clustering-based, not DDL-partition-based.
- **Pitfall:** Using `insert_overwrite` on a table with no clustering means every run is a full rewrite — use `merge` instead.
- **Pitfall:** Not including a look-back window for the previous period means corrections to prior month data will never be picked up.

---

## 🔹 Strategy: microbatch

### 1. Description

`microbatch` is a **dbt-native execution pattern** (introduced in dbt 1.9) that splits incremental processing into discrete, fixed-width time windows — called *batches* — and processes each batch independently. dbt orchestrates the batch loop; each batch runs as a separate query against Snowflake.

This is fundamentally different from the other strategies: the **dbt runner** manages the loop, not a single SQL statement. This enables retry at the batch level, parallel batch execution, and fine-grained observability.

Execution flow:
1. dbt determines the batch windows (e.g., every 1 hour from `lookback_start` to `now`).
2. For each window, dbt compiles and runs the model SQL with `event_time` bounded to that window.
3. Each window is written to the target using the underlying Snowflake strategy (typically `merge` or `insert_overwrite`).

### 2. Configuration

```yaml
# dbt_project.yml — enable microbatch
models:
  your_project:
    mart:
      +batch_size: day          # hour | day | month | year
      +lookback: 3              # re-process the last N batches on every run
      +begin: '2024-01-01'      # earliest batch start date
```

```sql
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'microbatch',
    event_time           = 'occurred_at',
    batch_size           = 'day',
    lookback             = 3,
    begin                = '2024-01-01'
) }}
```

| Option | Required | Notes |
|--------|----------|-------|
| `event_time` | Yes | The timestamp column dbt uses to define batch windows |
| `batch_size` | Yes | `hour` · `day` · `month` · `year` |
| `lookback` | No | Number of prior batches to reprocess on each run (absorbs late data) |
| `begin` | Yes | Earliest batch date; used on first run or full refresh |

### 3. Sample Data

**Source events across multiple days**

| event_id | user_id | occurred_at         | event_type |
|----------|---------|---------------------|-----------|
| e-001    | 5       | 2024-06-08 23:59:00 | purchase  |
| e-002    | 12      | 2024-06-09 00:01:00 | click     |
| e-003    | 7       | 2024-06-09 14:30:00 | pageview  |
| e-004    | 22      | 2024-06-10 08:00:00 | purchase  |

With `batch_size='day'` and `lookback=1`, a run on 2024-06-10 processes:
- Batch 1: `occurred_at >= 2024-06-09 AND occurred_at < 2024-06-10` (lookback)
- Batch 2: `occurred_at >= 2024-06-10 AND occurred_at < 2024-06-11` (current day)

### 4. Sample Model

```sql
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'microbatch',
    event_time           = 'occurred_at',
    batch_size           = 'day',
    lookback             = 3,
    begin                = '2024-01-01',
    cluster_by           = ['date(occurred_at)']
) }}

-- No is_incremental() filter needed — dbt injects the batch window filter
-- automatically via the event_time column.
select
    event_id,
    user_id,
    session_id,
    event_type,
    page_url,
    occurred_at,
    date(occurred_at)   as event_date
from {{ ref('stg_events') }}
```

> **No manual `is_incremental()` filter.** dbt automatically appends:
> `WHERE occurred_at >= '<batch_start>' AND occurred_at < '<batch_end>'`
> using the `event_time` column. Adding a manual filter on top will break batch slicing.

### 5. Key Behaviors

| Behavior | Detail |
|----------|--------|
| **Insert** | New events in the batch window are written |
| **Update** | Depends on underlying strategy; `merge` + `event_time` handles corrections |
| **Delete** | Not handled unless underlying strategy supports it |
| **Late data** | Handled by `lookback` — dbt reprocesses the last N batches every run |
| **Retry** | Failed batches can be retried independently with `--event-time-start/end` flags |
| **Performance** | Parallelism controlled by `dbt run --threads`; each batch is an independent query |

### 6. Verification Query

```sql
-- Confirm batch coverage — no gaps in event_date
select
    event_date,
    count(*)                        as event_count,
    min(occurred_at)                as earliest,
    max(occurred_at)                as latest
from {{ this }}
where event_date between '2024-06-07' and '2024-06-10'
group by 1
order by 1;

-- Confirm lookback reprocessed the expected window
select event_date, count(*) as row_count
from {{ this }}
where event_date >= dateadd('day', -4, current_date())
group by 1
order by 1;
```

### 7. When to Use

- Event streams or logs where late-arriving data is common and must be absorbed cleanly.
- Large historical backfills where processing all time in one query would time out.
- Pipelines that need batch-level retry without reprocessing the full table.
- Models with very high data volume where a single incremental query would scan too much.

### 8. Best Practices

- **Set `lookback` to match your SLA for late data.** If upstream guarantees events within 48 hours, `lookback=2` with `batch_size='day'` covers you.
- **Do not add `is_incremental()` filters.** dbt handles the window filter; adding a manual one double-filters or creates gaps.
- **Cluster on `date(event_time)`** to align Snowflake micro-partitions with batch boundaries — this dramatically reduces bytes scanned per batch.
- **Tune `batch_size` to your row volume.** If one day is 1B rows, use `hour`. If one day is 100K rows, `day` is fine.
- **Pitfall:** Setting `begin` too far in the past on a large table triggers a very long historical backfill on first run. Use `--event-time-start` to control the initial load window.
- **Pitfall:** `microbatch` is a dbt-layer feature — it requires dbt 1.9+ or dbt-fusion 2.x. It is not a native Snowflake construct.

---

## Strategy Comparison Matrix

| Strategy | Updates Rows | Hard Deletes | Requires Unique Key | Granularity | Best For | Relative Cost |
|----------|:-----------:|:------------:|:-------------------:|------------|---------|:------------:|
| `merge` | Yes | No | Yes (row-level) | Row | Mutable records with an `updated_at` watermark | Medium |
| `append` | No | No | No | Row | Immutable event streams, audit logs | Lowest |
| `delete+insert` | Yes (implicit) | Yes (partition) | Yes (partition col) | Date slice | Date-partitioned facts with late corrections | Medium |
| `insert_overwrite` | Yes (implicit) | Yes (partition) | No | Coarse partition | Monthly/weekly rollups, fully recomputed aggregates | Low–Medium |
| `microbatch` | Depends on sub-strategy | Depends | Yes (`event_time`) | Time window | High-volume event streams, late-data SLAs, backfills | Varies |

---

## Snowflake-Specific Notes

### How Snowflake Executes Each Strategy

| Strategy | Snowflake SQL Issued |
|----------|---------------------|
| `merge` | `MERGE INTO target USING source ON (key) WHEN MATCHED ... WHEN NOT MATCHED ...` |
| `append` | `INSERT INTO target SELECT ... FROM source` |
| `delete+insert` | `BEGIN; DELETE FROM target WHERE partition_col IN (...); INSERT INTO target SELECT ...; COMMIT;` |
| `insert_overwrite` | `INSERT OVERWRITE INTO target SELECT ... FROM source` |
| `microbatch` | Repeated `MERGE` or `INSERT OVERWRITE` calls per batch window, orchestrated by dbt |

### Differences vs BigQuery / Spark

| Topic | Snowflake | BigQuery | Spark |
|-------|-----------|---------|-------|
| Native partitions | No (clustering-based) | Yes (PARTITION BY) | Yes (PARTITION BY) |
| `insert_overwrite` | Truncate + re-insert (WHERE-clause scoped) | Partition-scoped DDL | Partition-scoped DDL |
| MERGE atomicity | Single statement | Single statement | Multiple tasks |
| Concurrency | Multi-cluster warehouse | Slot-based | Executor-based |
| `microbatch` | dbt-layer loop | dbt-layer loop | dbt-layer loop |

### Insert_overwrite on Snowflake — Truncate + Re-insert

The dbt docs describe `insert_overwrite` on Snowflake as behaving like **truncate + re-insert**, not as a partition-scoped operation. The adapter emits `INSERT OVERWRITE INTO <target> SELECT ...`, which deletes all rows in the destination and reinserts whatever the SELECT returns.

**What controls the scope of the overwrite** is the `is_incremental()` WHERE clause in your model — not the clustering key. A model with a filter like `WHERE visit_date >= date_trunc('month', dateadd('month', -1, current_date()))` will only replace rows in that window. A model with no filter will replace the entire table.

**What `cluster_by` does** is purely a performance optimisation: it lets Snowflake prune micro-partitions before scanning, reducing bytes read during the overwrite. It does not change which rows get replaced.

| Scenario | Outcome |
|---|---|
| `is_incremental()` filter present | Only the filtered rows are replaced — correct behaviour |
| No `is_incremental()` filter | Entire table is truncated and rebuilt on every run |
| `cluster_by` present | Micro-partition pruning speeds up the overwrite — same correctness |
| No `cluster_by` | Full micro-partition scan — slower, but same correctness as above |

**Differences vs BigQuery:** BigQuery's `INSERT OVERWRITE` is natively partition-scoped via `PARTITION BY` columns. Snowflake has no named partitions, so the overwrite scope is always determined by the SQL WHERE clause, not by a partition key.

### Micro-Partition Considerations

Snowflake automatically divides tables into compressed micro-partitions (~16MB each). DML performance — especially for `merge` and `delete+insert` — depends on how well the WHERE clause aligns with partition boundaries:

- **Clustered tables** prune micro-partitions before scanning, dramatically reducing bytes scanned.
- **Unclustered tables** with timestamp filters still benefit from Snowflake's automatic clustering (for small tables), but degrade for large tables over time.
- Run `SYSTEM$CLUSTERING_INFORMATION('<table>')` to inspect clustering depth.
- Use `AUTOMATIC CLUSTERING` in Snowflake for tables that grow continuously.

### Clustering Recommendations by Strategy

| Strategy | Recommended `cluster_by` |
|----------|--------------------------|
| `merge` | `[updated_at::date]` or `[surrogate_key]` (for small tables) |
| `append` | `[event_date]` or `[date(occurred_at)]` |
| `delete+insert` | `[partition_col]` — **required** |
| `insert_overwrite` | `[partition_col]` — strongly recommended for performance, not required for correctness |
| `microbatch` | `[date(event_time)]` — aligned to batch windows |

---

## Watermark Guidance

A watermark is the column (or expression) used in the `is_incremental()` filter to identify which rows are new since the last run. Choosing the wrong column is the most common source of silent data quality issues.

### merge → use `updated_at`

```sql
{% if is_incremental() %}
    where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

- **Column requirement:** The source must update `updated_at` on every row change. If your upstream system only sets `created_at`, you cannot detect updates — switch to `delete+insert`.
- **Strict `>`:** Using `>=` reprocesses the boundary row every run; use strict greater-than.
- **NULL safety:** If `updated_at` can be NULL in the source, wrap with `coalesce(updated_at, '1970-01-01')`.

### append → optional (but recommended)

```sql
{% if is_incremental() %}
    where event_id not in (select event_id from {{ this }})
    -- OR (preferred for performance):
    where occurred_at > (select coalesce(max(occurred_at), '1970-01-01') from {{ this }})
{% endif %}
```

- The `NOT IN` pattern is safe but scans the full target on every run for deduplication.
- The timestamp watermark is faster but misses rows that arrive out of order.
- For truly immutable streams with guaranteed ordering, use the timestamp watermark.

### delete+insert → use the partition column

```sql
{% if is_incremental() %}
    where sale_date >= (select dateadd('day', -3, max(sale_date)) from {{ this }})
{% endif %}
```

- The watermark is the partition boundary, not a row-level `updated_at`.
- The look-back window (`-3 days`) absorbs late corrections. Match this to your upstream SLA.
- Do not use row-level `updated_at` here — it will produce partial partition loads.

### insert_overwrite → partition-based filtering

```sql
{% if is_incremental() %}
    where sale_date >= date_trunc('month', dateadd('month', -1, current_date()))
{% endif %}
```

- Filter by the coarse partition unit (month/week), not by individual `updated_at` timestamps.
- The partition is the unit of work: all rows for that partition are recomputed.

### microbatch → no manual watermark

```sql
-- DO NOT add is_incremental() here
-- dbt injects: WHERE occurred_at >= '<batch_start>' AND occurred_at < '<batch_end>'
select * from {{ ref('stg_events') }}
```

- dbt manages the batch window automatically via `event_time`.
- Adding a manual watermark filter on top will either double-filter rows or skip data.

---

## Common Mistakes

### 1. Wrong Watermark Column

**Symptom:** Model runs without errors but the target table is missing updates from the last few days.

**Cause:** Using `created_at` as the watermark when rows are updated after creation. `created_at` never changes, so the incremental filter excludes all modified rows.

```sql
-- WRONG: misses updates to existing rows
where created_at > (select max(created_at) from {{ this }})

-- CORRECT: captures both new and updated rows
where updated_at > (select max(updated_at) from {{ this }})
```

**Fix:** Confirm your source system maintains a reliable `updated_at` (or equivalent) column that changes on every row modification.

---

### 2. Missing `is_incremental()` Guard

**Symptom:** Incremental model costs as much as a full refresh. Row counts match a full scan.

**Cause:** The filter clause exists but is not wrapped in `{% if is_incremental() %}`, so it runs unconditionally — or the clause is omitted entirely.

```sql
-- WRONG: filter runs even on first build, may error (this doesn't exist yet)
where updated_at > (select max(updated_at) from {{ this }})

-- CORRECT
{% if is_incremental() %}
    where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

**Fix:** Always wrap watermark filters in `{% if is_incremental() %}`. On first run or `--full-refresh`, `is_incremental()` returns false and the full table is loaded.

---

### 3. Using `append` for Mutable Data

**Symptom:** Target table row count grows indefinitely. Downstream reports show inflated metrics or duplicate records.

**Cause:** A mutable source (orders, users, subscriptions) was modeled with `append` instead of `merge`. Every updated row is re-inserted rather than overwriting the old version.

```yaml
# WRONG: orders change status after creation
config:
  materialized: incremental
  incremental_strategy: append

# CORRECT: use merge with a unique_key
config:
  materialized: incremental
  incremental_strategy: merge
  unique_key: order_id
```

**Fix:** Audit your source. If any column other than `created_at` can change after the row's creation, use `merge` or `delete+insert`.

---

### 4. Not Handling Late-Arriving Data

**Symptom:** Historical date partitions in the target are frozen even though upstream corrections arrive days later.

**Cause:** Watermark is set to `max(date)` with no look-back buffer. Any event with a timestamp older than the current watermark is silently dropped.

```sql
-- WRONG: only loads today's data, discards T-2 corrections
{% if is_incremental() %}
    where event_date = current_date()
{% endif %}

-- CORRECT: reloads the last 3 days to absorb late data
{% if is_incremental() %}
    where event_date >= dateadd('day', -3, current_date())
{% endif %}
```

**Fix:** Add a look-back window sized to your upstream SLA. For `microbatch`, use the `lookback` config parameter instead.

---

### 5. No Clustering on Large Tables

**Symptom:** Incremental runs are slow and expensive even though only a small date range is processed.

**Cause:** The target table has no `cluster_by`, so Snowflake must scan all micro-partitions on every `DELETE`, `MERGE`, or `INSERT OVERWRITE`.

```sql
-- Add clustering aligned to your watermark or partition column
{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'delete+insert',
    unique_key           = 'event_date',
    cluster_by           = ['event_date']   -- <<< add this
) }}
```

**Fix:** Cluster on the column used in your watermark filter. Enable `AUTOMATIC CLUSTERING` in Snowflake for tables that grow faster than manual re-clustering can keep up.

---

### 6. Using `>=` Instead of `>` on the Watermark Boundary

**Symptom:** The boundary row is processed on every run, inflating row counts or causing duplicate keys in downstream models.

**Cause:** `>= max(col)` includes the maximum row from the previous run every time.

```sql
-- WRONG: reprocesses the max row every run
where updated_at >= (select max(updated_at) from {{ this }})

-- CORRECT: strictly excludes the already-processed boundary
where updated_at > (select max(updated_at) from {{ this }})
```

**Fix:** Use strict greater-than `>` for timestamp watermarks. The boundary row was already loaded in the previous run.

---

## Sample Data Seeds

Five CSV seed files live in `seeds/macro_demos/` — one per incremental strategy demo.
Load them all with:

```bash
dbt seed --select demo_21_sample_merge demo_22_sample_append demo_23_sample_delete_insert demo_24_sample_insert_overwrite demo_25_sample_microbatch
```

They land in the `macro_demos_sample` schema in Snowflake and are independent of the
live fact tables. Use them to inspect the expected output shape of each model without
running a full dbt build.

### Seed → Demo Mapping

| Seed file | Demo model | Strategy | Source fact table | Rows |
|---|---|---|---|---|
| `demo_21_sample_merge.csv` | `demo_21_incremental_merge` | `merge` | `fct_all_ticket_sales` | 10 |
| `demo_22_sample_append.csv` | `demo_22_incremental_append` | `append` | `fct_sales` | 10 |
| `demo_23_sample_delete_insert.csv` | `demo_23_incremental_delete_insert` | `delete+insert` | `fct_visits` | 8 |
| `demo_24_sample_insert_overwrite.csv` | `demo_24_incremental_insert_overwrite` | `insert_overwrite` | `fct_sales` | 9 |
| `demo_25_sample_microbatch.csv` | `demo_25_incremental_microbatch` | `microbatch` | `fct_all_ticket_sales` | 10 |

---

### demo_21_sample_merge.csv — merge

Represents the **target table state after an incremental merge** on `fct_all_ticket_sales`.

- `unique_key = sale_id` — one row per ticket sale; duplicates trigger UPDATE, not INSERT
- `merge_update_columns` covers `ticket_price`, `discount_percent`, `discount_category`, `updated_at` only — `created_at` is never overwritten
- Rows **SL1003** and **SL1005** have `updated_at` newer than `created_at`, showing the MATCHED → UPDATE branch: price was corrected after the initial sale
- `incremental_predicates` limits the MERGE scan to the last 90 days of the target table (`DBT_INTERNAL_DEST.purchase_date >= dateadd('day', -90, current_date())`)

Key columns: `sale_id`, `purchase_date`, `visit_date`, `ticket_price`, `discount_category`, `visit_time_category`, `business_season`, `created_at`, `updated_at`

---

### demo_22_sample_append.csv — append

Represents a **growing immutable ledger** of in-park sales transactions from `fct_sales`.

- No `unique_key` — pure `INSERT INTO ... SELECT`, no MERGE overhead
- `_loaded_at` is stamped at query execution time; compare batches with the same `visit_date` range to detect accidental pipeline replays
- `full_refresh = false` is set on the model — the seed mirrors this by covering multiple `visit_date` batches that should never be wiped
- Rows are grouped into 4 distinct visit-date batches (Oct 31, Nov 2, Dec 24, Jan 11, Mar 22) showing how the ledger grows over time

Key columns: `sales_key`, `transaction_id`, `visit_date`, `category`, `total_amount`, `_loaded_at`

---

### demo_23_sample_delete_insert.csv — delete+insert

Represents a **daily aggregated visit summary** produced by `demo_23_incremental_delete_insert` from `fct_visits`.

- `unique_key = visit_date` is the **partition boundary**, not a row-level PK — all rows sharing a `visit_date` are deleted and rewritten together
- 8 rows span 4 consecutive days (Oct 31 – Nov 3) × 2 `ticket_type` values, showing the partition shape
- Each run reprocesses the last 3 days from the target's `max(visit_date)` to absorb late-arriving visit records

Key columns: `visit_date`, `ticket_type`, `unique_visitors`, `total_visits`, `total_ticket_revenue`, `avg_satisfaction_rating`

---

### demo_24_sample_insert_overwrite.csv — insert_overwrite

Represents a **monthly revenue rollup** produced by `demo_24_incremental_insert_overwrite` from `fct_sales`.

- `revenue_month` is always the **first day of the month** (result of `date_trunc('month', visit_date)`) — this is the overwrite partition key
- `cluster_by = ['revenue_month']` on the model is **required**; without it, INSERT OVERWRITE replaces the entire table on every run
- 9 rows span Oct 2024, Nov 2024, Dec 2024, Jan 2025 across different category/location/payment_method slices
- On each run only the current month and prior month partitions are overwritten; older months remain untouched

Key columns: `revenue_month`, `category`, `location`, `payment_method`, `total_revenue`, `unique_customers`

---

### demo_25_sample_microbatch.csv — microbatch

Represents **one daily batch window** of ticket sales produced by `demo_25_incremental_microbatch` from `fct_all_ticket_sales`.

- `event_time = 'purchase_ts'` — dbt injects `WHERE purchase_ts >= batch_start AND purchase_ts < batch_end` automatically; **no `is_incremental()` block in the model**
- `purchase_ts` = `purchase_date::TIMESTAMP_NTZ` (source column `purchase_timestamp` is NULL; the alias is derived in the SELECT)
- All 10 rows have `purchase_date` in the Oct 15–24 2024 range, matching the `begin = '2024-10-01'` config and the bounded `--event-time-start / --event-time-end` range used on first load
- `lookback = 3` means the last 3 completed day batches are reprocessed on every run to absorb late-arriving source rows

Key columns: `sale_id`, `purchase_date`, `purchase_ts`, `visit_date`, `discount_category`, `business_season`
