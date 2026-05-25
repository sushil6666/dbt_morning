{#
  apply_cluster_by(cluster_columns)
  Post-hook macro: applies Snowflake CLUSTER BY to the built table.
  Only fires on Snowflake — safe to add to all models, no-ops on other adapters.
  Makes clustering version-controlled and automatic on every deploy.
  Usage (in model config post_hook):
    "{{ apply_cluster_by(['visit_date', 'customer_id']) }}"
#}

{% macro apply_cluster_by(cluster_columns) %}

    {% if target.type == 'snowflake' %}
        ALTER TABLE {{ this }}
        CLUSTER BY ({{ cluster_columns | join(', ') }})
    {% endif %}

{% endmacro %}
