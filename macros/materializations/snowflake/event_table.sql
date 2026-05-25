{% materialization event_table, adapter='snowflake' %}

    {%- set _model_sql = sql -%}

    {#- Event tables are schema-only objects — no AS SELECT. They receive rows
        via system-level event routing, not user DML. This materialization
        creates (or replaces) the event table and is intentionally idempotent. -#}

    {%- set relation = this.incorporate(type='table') -%}

    {%- set meta                = config.get('meta', {}) -%}
    {%- set cluster_by          = config.get('cluster_by') -%}
    {%- set data_retention_days = meta.get('data_retention_time_in_days') -%}

    {%- set extra_props = [] -%}
    {%- if cluster_by -%}
        {%- do extra_props.append("CLUSTER BY (" ~ cluster_by ~ ")") -%}
    {%- endif -%}
    {%- if data_retention_days is not none -%}
        {%- do extra_props.append("DATA_RETENTION_TIME_IN_DAYS = " ~ data_retention_days) -%}
    {%- endif -%}

    {%- set extra_ddl = extra_props | join('\n') -%}

    {% call statement('main') %}
        {{ sf_create_table_as(
            relation   = relation,
            sql        = '',
            table_type = 'event',
            extra_ddl  = extra_ddl
        ) }}
    {% endcall %}

    {{ return({'relations': [relation]}) }}

{% endmaterialization %}
