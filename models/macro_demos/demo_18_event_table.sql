{{
    config(
        materialized = 'event_table',
        tags         = ['macro_demo', 'demo_18', 'custom_materialization'],
        meta         = {'data_retention_time_in_days': 7}
    )
}}

/*
  demo_18_event_table
  -------------------
  Tests the custom `event_table` materialization (macros/materializations/snowflake/event_table.sql).

  Snowflake EVENT TABLES are schema-only DDL objects — they capture telemetry
  events (logs, traces, spans) routed by Snowflake's observability framework.
  They cannot be populated via SELECT; rows arrive via system routing only.

  This model creates the table structure with a 7-day data retention window.
  The materialization intentionally emits no SQL body — the `create_table_as`
  helper skips the `AS (...)` clause for event type.

  To confirm the table was created:
      SHOW EVENT TABLES IN SCHEMA <your_schema>;
*/

-- No SELECT body — event tables receive rows via Snowflake telemetry routing,
-- not via user DML.  The model file must exist for dbt to manage the relation.
SELECT 1 AS placeholder WHERE 1 = 0
