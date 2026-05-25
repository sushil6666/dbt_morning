{#
  audit_columns()
  Injects 4 standard audit columns into any mart SELECT list.
  Enables SOX-style pipeline traceability — every row carries the run that produced it.
  Usage: {{ audit_columns() }}  — add as last columns in any mart SELECT
#}

{% macro audit_columns() %}

    CURRENT_TIMESTAMP()         AS dbt_updated_at,
    '{{ invocation_id }}'       AS dbt_run_id,
    '{{ this.name }}'           AS dbt_model_name,
    '{{ target.name }}'         AS dbt_env

{% endmacro %}
