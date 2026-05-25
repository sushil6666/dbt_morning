{{
    config(
        materialized = 'dynamic_table',
        tags         = ['macro_demo', 'demo_27', 'custom_materialization'],
        meta         = {
            'target_lag'   : '1 minute',
            'warehouse'    : 'COMPUTE_WH',
            'refresh_mode' : 'AUTO',
            'initialize'   : 'ON_CREATE'
        }
    )
}}

{#
  demo_27_dynamic_table
  -----------------------------------------------------------------------
  MATERIALIZATION: dynamic_table  (custom — macros/materializations/snowflake/dynamic_table.sql)

  WHAT IS A SNOWFLAKE DYNAMIC TABLE?
  ------------------------------------
  A Dynamic Table is a declarative, continuously-refreshed table in
  Snowflake.  You define a query; Snowflake automatically re-executes it
  (incrementally when possible) to keep the result fresh within your
  specified TARGET_LAG.

  Unlike a standard materialized view, a Dynamic Table:
    • Supports multi-level pipelines  — dynamic tables can ref other dynamic tables.
    • Uses incremental computation    — Snowflake tracks what changed and only
                                        re-processes new/modified rows (REFRESH_MODE = AUTO / INCREMENTAL).
    • Is warehouse-driven             — consumes credits from a designated warehouse.
    • Integrates with Snowflake Tasks — can be used as a DOWNSTREAM target trigger.

  KEY CONFIG OPTIONS  (all passed inside the `meta` dict)
  ---------------------------------------------------------
  target_lag   REQUIRED  How stale the data can be.
                          '1 minute'   → refresh at most 1 minute behind base tables.
                          'DOWNSTREAM' → refresh only when downstream objects need it.
                          Values: '<number> { second | minute | hour | day }' or 'DOWNSTREAM'

  warehouse    REQUIRED  Virtual warehouse that powers the automatic refresh jobs.
                          Example: 'COMPUTE_WH'

  refresh_mode OPTIONAL  AUTO        (default) — Snowflake chooses INCREMENTAL when
                                       possible, falls back to FULL otherwise.
                          INCREMENTAL — always incremental (fails if not supported).
                          FULL        — always full re-materialisation.

  initialize   OPTIONAL  ON_CREATE   (default) — populates data immediately at creation.
                          ON_SCHEDULE — waits until the next scheduled refresh cycle.

  GENERATED DDL
  -------------
  CREATE OR REPLACE DYNAMIC TABLE <schema>.<model>
      TARGET_LAG   = '1 minute'
      WAREHOUSE    = COMPUTE_WH
      REFRESH_MODE = AUTO
      INITIALIZE   = ON_CREATE
  AS (
      <model SQL>
  )

  THIS MODEL
  ----------
  Builds a continuously-refreshed sales summary aggregated by
  visit_date × category × location — a typical real-time analytics
  use case where dashboards need sub-minute data freshness without
  running expensive scheduled tasks.

  PREREQUISITES
  -------------
  • The Snowflake role used by dbt must have CREATE DYNAMIC TABLE privilege
    on the target schema:
        GRANT CREATE DYNAMIC TABLE ON SCHEMA <db>.<schema> TO ROLE <dbt_role>;
  • The warehouse referenced in `warehouse` config must exist and the role
    must have USAGE + OPERATE privileges on it.

  TRY IT
  ------
  dbt run  -s demo_27_dynamic_table          -- creates the dynamic table
  dbt compile -s demo_27_dynamic_table       -- inspect the emitted DDL

  In Snowflake:
    SHOW DYNAMIC TABLES LIKE 'DEMO_27_DYNAMIC_TABLE%';
    DESCRIBE DYNAMIC TABLE <db>.<schema>.DEMO_27_DYNAMIC_TABLE;
    ALTER  DYNAMIC TABLE <db>.<schema>.DEMO_27_DYNAMIC_TABLE REFRESH;   -- manual trigger
    ALTER  DYNAMIC TABLE <db>.<schema>.DEMO_27_DYNAMIC_TABLE SUSPEND;   -- pause auto-refresh
    ALTER  DYNAMIC TABLE <db>.<schema>.DEMO_27_DYNAMIC_TABLE RESUME;    -- re-enable
#}

WITH sales AS (

    SELECT
        visit_date,
        category,
        location,
        total_amount
    FROM {{ ref('fct_sales') }}

)

SELECT
    visit_date,
    category,
    location,
    COUNT(*)                        AS transaction_count,
    SUM(total_amount)               AS total_revenue,
    AVG(total_amount)               AS avg_transaction_value,
    MIN(total_amount)               AS min_transaction_value,
    MAX(total_amount)               AS max_transaction_value
FROM sales
GROUP BY
    visit_date,
    category,
    location
