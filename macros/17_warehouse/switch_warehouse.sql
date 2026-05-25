{#
  switch_warehouse(warehouse)  /  reset_warehouse()
  -----------------------------------------------------------------------
  Pre/post-hook pair for per-model warehouse sizing.

  switch_warehouse(warehouse)
    Issues USE WAREHOUSE <warehouse> before the model runs.
    Lets a single heavy model scale up without changing the profile default.

  reset_warehouse()
    Issues USE WAREHOUSE <target.warehouse> after the model finishes,
    restoring the warehouse configured in profiles.yml for this target.
    Always pair with switch_warehouse so the session stays clean for the
    next model in the run.

  SNOWFLAKE BEHAVIOUR:
    USE WAREHOUSE switches the active virtual warehouse for the current
    session only. Other concurrent sessions are unaffected.
    Credit billing starts on the new warehouse immediately.

  USAGE (in model config — must be single-line string in dbt-fusion):
    pre_hook="{{ switch_warehouse(var('heavy_model_warehouse', 'DBT_WH')) }}"
    post_hook="{{ reset_warehouse() }}"

  WHY VAR NOT HARDCODE:
    Warehouse names differ across environments (dev = COMPUTE_WH,
    prod = COMPUTE_WH_LARGE). A var keeps the model portable.
    Set heavy_model_warehouse in dbt_project.yml per-environment or
    override from the CLI / CI/CD job env vars.
#}

{% macro switch_warehouse(warehouse) %}
    {% if execute %}
        USE WAREHOUSE {{ warehouse }};
    {% endif %}
{% endmacro %}


{% macro reset_warehouse() %}
    {% if execute %}
        USE WAREHOUSE {{ target.warehouse }};
    {% endif %}
{% endmacro %}
