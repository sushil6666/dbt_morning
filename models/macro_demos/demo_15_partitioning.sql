{{ config(
    materialized='incremental',
    unique_key='ticket_id',
    tags=['macro_demo', 'demo_15'],
    post_hook="{{ get_cluster_by_sql(var('cluster_columns', ['visit_date', 'ticket_type'])) }}"
) }}

{#
  Snowflake: CLUSTER BY (visit_date, ticket_type) applied via post-hook.
  Override cluster columns at runtime:
    dbt run --vars '{"cluster_columns": ["visit_date", "customer_id"]}' --select demo_15_partitioning
  BigQuery: swap get_cluster_by_sql for a partition_by config key (see macro docs).
#}

SELECT
    ticket_id,
    customer_id,
    visit_date,
    ticket_type,
    total_visit_spend,
    avg_rating
FROM {{ ref('fct_visits') }}

{% if is_incremental() %}
WHERE {{ incremental_filter('visit_date') }}
{% endif %}
