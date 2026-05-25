{{
    config(
        materialized = 'hybrid_table',
        primary_key  = 'ticket_id',
        tags         = ['macro_demo', 'demo_17', 'custom_materialization'],
        enabled      = false
    )
}}

/*
  demo_17_hybrid_table
  --------------------
  Tests the custom `hybrid_table` materialization (macros/materializations/snowflake/hybrid_table.sql).

  Hybrid tables in Snowflake support both analytical (columnar) and
  row-level operational workloads.  They REQUIRE a PRIMARY KEY — the
  materialization will raise a compiler error if `primary_key` is absent.

  Uses `ticket_id` as PK (guaranteed unique from fct_visits).
*/

SELECT
    ticket_id,
    customer_id,
    visit_date,
    ticket_type,
    ticket_price,
    in_park_spend,
    total_visit_spend,
    avg_rating
FROM {{ ref('fct_visits') }}
