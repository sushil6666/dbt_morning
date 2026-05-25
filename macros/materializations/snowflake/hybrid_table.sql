{% materialization hybrid_table, adapter='snowflake' %}

    {%- set primary_key = config.get('primary_key') -%}

    {%- if not primary_key -%}
        {{ exceptions.raise_compiler_error(
            "hybrid_table materialization requires `primary_key` in config. "
            ~ "Example: {{ config(materialized='hybrid_table', primary_key='id') }}"
        ) }}
    {%- endif -%}

    {#- dbt-fusion may surface primary_key as a list even when a string is specified;
        normalise to a comma-separated string in both cases. -#}
    {%- if primary_key is string -%}
        {%- set pk_cols = primary_key -%}
    {%- else -%}
        {%- set pk_cols = primary_key | join(', ') -%}
    {%- endif -%}

    {%- set relation  = this.incorporate(type='table') -%}
    {%- set model_sql = sql -%}

    {#- Hybrid tables do not support CREATE OR REPLACE ... AS SELECT directly;
        materialise via a staging temp table then INSERT SELECT. -#}

    {%- set staging = make_temp_relation(this) -%}

    {{ run_query(
        sf_create_table_as(
            relation   = staging,
            sql        = model_sql,
            table_type = 'temporary'
        )
    ) }}

    {#- Build column definitions with both name and data type for the CREATE DDL. -#}
    {%- set columns = adapter.get_columns_in_relation(staging) -%}
    {%- set col_defs = [] -%}
    {%- for col in columns -%}
        {%- do col_defs.append(col.quoted ~ ' ' ~ col.dtype) -%}
    {%- endfor -%}

    {%- set hybrid_ddl -%}
        CREATE OR REPLACE HYBRID TABLE {{ relation }} (
            {{ col_defs | join(',\n            ') }},
            PRIMARY KEY ({{ pk_cols }})
        )
    {%- endset -%}

    {{ run_query(hybrid_ddl) }}

    {{ run_query(
        "INSERT INTO " ~ relation ~ " SELECT * FROM " ~ staging
    ) }}

    {{ return({'relations': [relation]}) }}

{% endmaterialization %}
