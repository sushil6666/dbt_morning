{{
    config(
        materialized = 'temp_table',
        tags         = ['macro_demo', 'demo_16', 'custom_materialization']
    )
}}

/*
  demo_16_temp_table
  ------------------
  Tests the custom `temp_table` materialization (macros/materializations/snowflake/temp_table.sql).

  Produces a session-scoped TEMPORARY TABLE in Snowflake that holds a
  lightweight visit summary.  Temporary tables are ideal for intermediate
  computation layers that don't need to persist beyond the run session.
*/

SELECT
    ticket_type,
    COUNT(*)                        AS total_visits,
    ROUND(AVG(total_visit_spend), 2) AS avg_spend,
    ROUND(AVG(avg_rating), 2)        AS avg_rating,
    MIN(visit_date)                  AS first_visit,
    MAX(visit_date)                  AS last_visit
FROM {{ ref('fct_visits') }}
GROUP BY ticket_type
