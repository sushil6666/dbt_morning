{% materialization dynamic_table, adapter='snowflake' %}

    {%- set meta         = config.get('meta', {}) -%}
    {%- set target_lag   = meta.get('target_lag') -%}
    {%- set warehouse    = meta.get('warehouse') -%}
    {%- set refresh_mode = (meta.get('refresh_mode', 'AUTO')) | upper -%}
    {%- set initialize   = (meta.get('initialize', 'ON_CREATE')) | upper -%}

    {#- ------------------------------------------------------------------ -#}
    {#-  Validation                                                         -#}
    {#- ------------------------------------------------------------------ -#}
    {%- if not target_lag -%}
        {{ exceptions.raise_compiler_error(
            "dynamic_table materialization requires `target_lag` in config.\n"
            ~ "Examples:\n"
            ~ "  target_lag = '1 minute'     -- refresh at most 1 minute behind sources\n"
            ~ "  target_lag = 'DOWNSTREAM'   -- refresh only when a downstream object refreshes"
        ) }}
    {%- endif -%}

    {%- if not warehouse -%}
        {{ exceptions.raise_compiler_error(
            "dynamic_table materialization requires `warehouse` in config.\n"
            ~ "Example:\n"
            ~ "  warehouse = 'COMPUTE_WH'"
        ) }}
    {%- endif -%}

    {%- set valid_refresh_modes = ['AUTO', 'FULL', 'INCREMENTAL'] -%}
    {%- if refresh_mode not in valid_refresh_modes -%}
        {{ exceptions.raise_compiler_error(
            "dynamic_table `refresh_mode` must be one of: AUTO, FULL, INCREMENTAL. "
            ~ "Got: '" ~ refresh_mode ~ "'"
        ) }}
    {%- endif -%}

    {%- set valid_initialize = ['ON_CREATE', 'ON_SCHEDULE'] -%}
    {%- if initialize not in valid_initialize -%}
        {{ exceptions.raise_compiler_error(
            "dynamic_table `initialize` must be one of: ON_CREATE, ON_SCHEDULE. "
            ~ "Got: '" ~ initialize ~ "'"
        ) }}
    {%- endif -%}

    {#- ------------------------------------------------------------------ -#}
    {#-  Build the relation typed as 'table' so dbt tracks it correctly     -#}
    {#- ------------------------------------------------------------------ -#}
    {%- set relation  = this.incorporate(type='table') -%}
    {%- set model_sql = sql -%}

    {%- call statement('main') -%}
        CREATE OR REPLACE DYNAMIC TABLE {{ relation }}
            TARGET_LAG  = '{{ target_lag }}'
            WAREHOUSE   = {{ warehouse }}
            REFRESH_MODE = {{ refresh_mode }}
            INITIALIZE   = {{ initialize }}
        AS (
            {{ model_sql }}
        )
    {%- endcall -%}

    {{ return({'relations': [relation]}) }}

{% endmaterialization %}
