{#
  feature_flag(flag_name, default=false)
  Reads a boolean var to toggle experimental model logic on/off.
  Enables A/B validation of new business logic in the same model file —
  no separate branch, no separate model, no merge conflicts.
  Usage: {% if feature_flag('use_new_pricing_model') %} ... {% else %} ... {% endif %}
  Activate via CLI: dbt run --vars '{"use_new_pricing_model": true}'
#}

{% macro feature_flag(flag_name, default=false) %}

    {{ return(var(flag_name, default) | as_bool) }}

{% endmacro %}
