{% macro create_schema(relation) %}
    {%- call statement('create_schema', fetch_result=False) -%}
        CREATE SCHEMA IF NOT EXISTS {{ relation.database }}.{{ relation.schema }}
    {%- endcall -%}
    {{ log("Created schema (if not exists): " ~ relation.database ~ "." ~ relation.schema, info=true) }}
{% endmacro %}

{% macro safe_create_target_schema(schema_name) %}
    {% if not execute %}
        {{ return('') }}
    {% endif %}

    {% set relation = api.Relation.create(database=target.database, schema=schema_name) %}

    {% if target.database is none or (target.database | trim) == '' %}
        {{ log("Skipping schema creation because target.database is empty", info=true) }}
        {{ return('select 1') }}
    {% endif %}

    {% set current_db_query %}
        select current_database()
    {% endset %}

    {% set current_db_result = run_query(current_db_query) %}
    {% set current_db = current_db_result.columns[0].values()[0] if current_db_result is not none else none %}

    {% if current_db is none %}
        {{ log("Skipping schema creation because current_database() returned no value", info=true) }}
        {{ return('select 1') }}
    {% endif %}

    {% if current_db | upper != target.database | upper %}
        {{ log("Skipping schema creation for " ~ target.database ~ "." ~ schema_name ~ " because current database is " ~ current_db, info=true) }}
        {{ return('select 1') }}
    {% endif %}

    {% do create_schema(relation) %}

    {{ return('select 1') }}
{% endmacro %}
