{#
  swap_schemas(candidate_schema, prod_schema, database, keep_backup)

  WAP "Publish" step — promotes the candidate schema into prod via schema renames.
  All three operations are metadata-only in Snowflake (no data movement), so the
  window where prod is unavailable is milliseconds.

  Typical usage (run AFTER dbt test --target candidate passes):
    dbt run-operation swap_schemas \
      --args '{"candidate_schema": "DBT_BATCH_CANDIDATE", "prod_schema": "DBT_BATCH_PROD"}' \
      --target prod

  Args:
    candidate_schema  Schema to promote (default: current target schema)
    prod_schema       Schema to replace  (required)
    database          Snowflake database  (default: current target database)
    keep_backup       If true, prod is renamed to {prod}_backup instead of dropped (default: false)
#}

{% macro swap_schemas(
    candidate_schema = none,
    prod_schema       = none,
    database          = none,
    keep_backup       = false
) %}

    {%- set db  = database         | default(target.database, boolean=true) -%}
    {%- set src = candidate_schema | default(target.schema,   boolean=true) -%}
    {%- set tgt = prod_schema -%}

    {%- if tgt is none -%}
        {{ exceptions.raise_compiler_error("swap_schemas: prod_schema is required") }}
    {%- endif -%}

    {%- set backup = tgt ~ '_BACKUP' -%}

    {% call statement('drop_old_backup', fetch_result=false) %}
        DROP SCHEMA IF EXISTS {{ db }}.{{ backup }}
    {% endcall %}

    {% call statement('rename_prod_to_backup', fetch_result=false) %}
        ALTER SCHEMA {{ db }}.{{ tgt }} RENAME TO {{ db }}.{{ backup }}
    {% endcall %}

    {% call statement('promote_candidate_to_prod', fetch_result=false) %}
        ALTER SCHEMA {{ db }}.{{ src }} RENAME TO {{ db }}.{{ tgt }}
    {% endcall %}

    {%- if not keep_backup %}
    {% call statement('drop_backup', fetch_result=false) %}
        DROP SCHEMA IF EXISTS {{ db }}.{{ backup }}
    {% endcall %}
    {%- endif %}

    {{ log("Swapped " ~ db ~ "." ~ src ~ " → " ~ db ~ "." ~ tgt, info=true) }}

{% endmacro %}
