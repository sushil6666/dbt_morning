{#
  generate_base_model(
      source_name,
      table_name,
      column_mapping,
      where_clause=None,
      add_audit_columns=True,
      source_alias='src',
      casts=None,
      extra_expressions=None
  )

  Enterprise-friendly staging model generator.

  Features:
    - explicit source aliasing for predictable generated SQL
    - compiler-time validation for required arguments
    - optional target-column type casts via `casts={'col_name': 'varchar'}`
    - optional derived fields via `extra_expressions={'expr': 'alias_name'}`
    - standard audit columns via `audit_columns()`

  Notes:
    - `column_mapping` remains the primary required mapping of source/expression -> target column
    - keys that look like plain column names are qualified as `<source_alias>.<column>`
    - keys that look like expressions are rendered as-is
#}

{% macro generate_base_model(
    source_name,
    table_name,
    column_mapping,
    where_clause=None,
    add_audit_columns=True,
    source_alias='src',
    casts=None,
    extra_expressions=None
) %}

{% if not source_name or not table_name %}
    {{ exceptions.raise_compiler_error("generate_base_model requires both `source_name` and `table_name`.") }}
{% endif %}

{% if column_mapping is none or (column_mapping | length) == 0 %}
    {{ exceptions.raise_compiler_error("generate_base_model requires a non-empty `column_mapping` dictionary.") }}
{% endif %}

{% if casts is none %}
    {% set casts = {} %}
{% endif %}

{% if extra_expressions is none %}
    {% set extra_expressions = {} %}
{% endif %}

with source_data as (

    select *
    from {{ source(source_name, table_name) }} as {{ source_alias }}
    {% if where_clause is not none %}
    where {{ where_clause }}
    {% endif %}

),

renamed as (

    select
        {% for src, tgt in column_mapping.items() %}
        {% set src_trim = src | trim %}
        {% if src_trim.startswith('(') or ' ' in src_trim or '.' in src_trim %}
            {% set src_expr = src_trim %}
        {% else %}
            {% set src_expr = source_alias ~ '.' ~ src_trim %}
        {% endif %}

        {% if casts.get(tgt) %}
        cast({{ src_expr }} as {{ casts.get(tgt) }}) as {{ tgt }}
        {% else %}
        {{ src_expr }} as {{ tgt }}
        {% endif %}
        {% if not loop.last or (extra_expressions | length) > 0 or add_audit_columns %},{% endif %}
        {% endfor %}

        {% for expr, alias_name in extra_expressions.items() %}
        {{ expr }} as {{ alias_name }}{% if not loop.last or add_audit_columns %},{% endif %}
        {% endfor %}

        {% if add_audit_columns %}
        {{ audit_columns() }}
        {% endif %}
    from source_data as {{ source_alias }}

)

select *
from renamed

{% endmacro %}
