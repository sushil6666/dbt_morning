{% macro create_schema(relation) %}
    {%- call statement('create_schema') -%}
        CREATE SCHEMA IF NOT EXISTS {{ relation.database }}.{{ relation.schema }}
    {%- endcall -%}
    {{ log("Created schema (if not exists): " ~ relation.database ~ "." ~ relation.schema, info=true) }}
{% endmacro %}
