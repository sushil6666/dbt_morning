{#
  get_columns_except(relation, exclude_cols=[])
  Fetches all columns from a relation at compile time, minus any excluded names.
  New source columns automatically appear in the next dbt run — zero lag.
  Falls back to * during baseline introspection when no exclusions are requested.
  Usage: SELECT {{ get_columns_except(ref('stg_sales_transactions__sales_transactions'),
                    exclude_cols=['_fivetran_synced']) }}
#}

{% macro get_columns_except(relation, exclude_cols=[]) %}

    {% set cols = adapter.get_columns_in_relation(relation) %}
    {% set selected = [] %}
    {% for col in cols %}
        {% if col.name | lower not in exclude_cols | map('lower') | list %}
            {% do selected.append(col.name) %}
        {% endif %}
    {% endfor %}

    {% if selected | length > 0 %}
        {{ selected | join(', ') }}
    {% elif exclude_cols | length == 0 %}
        *
    {% else %}
        {{ exceptions.raise_compiler_error(
            "get_columns_except could not introspect " ~ relation ~
            "; refusing to use * because excluded columns were requested"
        ) }}
    {% endif %}

{% endmacro %}
