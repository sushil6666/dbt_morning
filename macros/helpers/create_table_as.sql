{% macro sf_create_table_as(relation, sql, table_type='table', extra_ddl='') %}

    {%- set table_type_clause -%}
        {%- if table_type | lower == 'temporary' -%}
            TEMPORARY TABLE
        {%- elif table_type | lower == 'hybrid' -%}
            HYBRID TABLE
        {%- elif table_type | lower == 'event' -%}
            EVENT TABLE
        {%- elif table_type | lower == 'iceberg' -%}
            ICEBERG TABLE
        {%- else -%}
            TABLE
        {%- endif -%}
    {%- endset -%}

    CREATE OR REPLACE {{ table_type_clause }} {{ relation }}
    {%- if extra_ddl %} {{ extra_ddl }}{% endif %}
    {%- if table_type | lower != 'event' %}
    AS (
        {{ sql }}
    )
    {%- endif %}

{% endmacro %}
