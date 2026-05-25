{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_13'],
    pre_hook="{{ apply_query_tag('analytics') }}",
    post_hook="{{ reset_query_tag() }}"
) }}

{#
  Every query run by this model will carry a structured JSON QUERY_TAG in Snowflake:
  { "model": "demo_13_query_tag", "env": "dev", "run_id": "...", "team": "analytics" }
  Inspect in Snowflake: SELECT QUERY_TAG, QUERY_TEXT FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
  Filter: PARSE_JSON(QUERY_TAG):team::string = 'analytics'
  NOTE: apply_query_tag (not set_query_tag) to avoid overriding the built-in dbt adapter macro.
#}

SELECT
    ticket_id,
    customer_id,
    visit_date,
    ticket_type,
    total_visit_spend,
    avg_rating
FROM {{ ref('fct_visits') }}
