{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {#
      WAP targets (uat, candidate, prod) must land everything in a single schema
      so that swap_schemas can atomically rename DBT_BATCH_CANDIDATE → DBT_BATCH_PROD.
      For dev/ci, use the custom schema name verbatim to preserve schema separation.
    #}
    {%- if target.name in ['uat', 'candidate', 'prod'] -%}

        {{ default_schema }}

    {%- elif custom_schema_name is none -%}

        {{ default_schema }}

    {%- else -%}

        {{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}