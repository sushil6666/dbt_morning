{#
  cross_db_surrogate_key(field_list)
  Generates a surrogate key using the correct MD5 syntax per adapter.
  Snowflake → MD5(CONCAT_WS), BigQuery → TO_HEX(MD5), DuckDB/Postgres → md5()
  Drop-in replacement for dbt_utils.generate_surrogate_key with full adapter control.
  Usage: {{ cross_db_surrogate_key(['ticket_id', 'customer_id', 'visit_date']) }} AS sk
#}

{% macro cross_db_surrogate_key(field_list) %}

    {{ log('cross_db_surrogate_key called on adapter=' ~ target.type ~ ' with fields=' ~ (field_list | join(', ')), info=True) }}

    {% if target.type == 'snowflake' %}
        {{ log('cross_db_surrogate_key using snowflake branch', info=True) }}
       {# {{ exceptions.raise_compiler_error(
            'DEBUG cross_db_surrogate_key snowflake branch | adapter=' ~ target.type ~
            ' | fields=' ~ (field_list | join(', ')) ~
            ' | rendered_expr=MD5(CAST(CONCAT_WS(''-'', ' ~ (field_list | join(', ')) ~ ') AS VARCHAR))'
        ) }} #}
        MD5(CAST(CONCAT_WS('-', {{ field_list | join(', ') }}) AS VARCHAR))


    {% elif target.type == 'bigquery' %}
        {{ log('cross_db_surrogate_key using bigquery branch', info=True) }}
        TO_HEX(MD5(CAST(CONCAT({{ field_list | join(" || '-' || ") }}) AS STRING)))
    {% elif target.type in ('duckdb', 'postgres') %}
        {{ log('cross_db_surrogate_key using duckdb/postgres branch', info=True) }}
        md5(cast({{ field_list | join(" || '-' || ") }} as varchar))
    {% else %}
        {{ log('cross_db_surrogate_key using fallback branch for adapter=' ~ target.type, info=True) }}
        MD5(CAST({{ field_list | join(" || '-' || ") }} AS VARCHAR))
    {% endif %}

{% endmacro %}
