{#
  cross_db_surrogate_key(field_list)
  Generates a surrogate key using the correct MD5 syntax per adapter.
  Snowflake → MD5(CONCAT_WS), BigQuery → TO_HEX(MD5), DuckDB/Postgres → md5()
  Drop-in replacement for dbt_utils.generate_surrogate_key with full adapter control.
  Usage: {{ cross_db_surrogate_key(['ticket_id', 'customer_id', 'visit_date']) }} AS sk
#}

{% macro cross_db_surrogate_key(field_list) %}

    {% if target.type == 'snowflake' %}
        MD5(CAST(CONCAT_WS('-', {{ field_list | join(', ') }}) AS VARCHAR))
    {% elif target.type == 'bigquery' %}
        TO_HEX(MD5(CAST(CONCAT({{ field_list | join(" || '-' || ") }}) AS STRING)))
    {% elif target.type in ('duckdb', 'postgres') %}
        md5(cast({{ field_list | join(" || '-' || ") }} as varchar))
    {% else %}
        MD5(CAST({{ field_list | join(" || '-' || ") }} AS VARCHAR))
    {% endif %}

{% endmacro %}
