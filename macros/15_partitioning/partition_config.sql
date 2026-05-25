{#
  get_partition_config(date_column, granularity='day')
  Generates adapter-appropriate partitioning / clustering DDL config.
  Snowflake has no native partitioning — emits a CLUSTER BY post-hook instead.
  BigQuery    → partition_by config dict (used in {{ config(...) }})
  Usage:
    Snowflake post_hook: "{{ get_cluster_by_sql(['visit_date', 'house_id']) }}"
    BigQuery config:     partition_by="{{ get_partition_config('visit_date', 'day') }}"

  get_cluster_by_sql(cluster_columns)
  Emits a ready-to-run Snowflake CLUSTER BY statement.
  Usage in post_hook: "{{ get_cluster_by_sql(['visit_date', 'house_id']) }}"
#}

{% macro get_partition_config(date_column, granularity='day') %}

    {% if target.type == 'bigquery' %}
        {
            "field": "{{ date_column }}",
            "data_type": "date",
            "granularity": "{{ granularity }}"
        }
    {% else %}
        {# Snowflake / other: no native partition — use cluster by instead #}
        {{ date_column }}
    {% endif %}

{% endmacro %}


{% macro get_cluster_by_sql(cluster_columns) %}

    {% if target.type == 'snowflake' %}
        ALTER TABLE {{ this }}
        CLUSTER BY ({{ cluster_columns | join(', ') }})
    {% endif %}

{% endmacro %}
