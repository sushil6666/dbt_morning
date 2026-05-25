{% materialization temp_table, adapter='snowflake' %}

    {%- set relation = this.incorporate(type='table') -%}
    {%- set model_sql = sql -%}

    {% call statement('main') %}
        {{ sf_create_table_as(
            relation   = relation,
            sql        = model_sql,
            table_type = 'temporary'
        ) }}
    {% endcall %}

    {{ return({'relations': [relation]}) }}

{% endmaterialization %}
