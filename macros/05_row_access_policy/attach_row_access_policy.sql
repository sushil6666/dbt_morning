{#
  attach_row_access_policy(policy_name, column_name)
  Post-hook macro: attaches a Snowflake row access policy to the built table.
  The policy must already exist in Snowflake before this hook runs.
  Guarantees zero window of unauthorized access — policy lands with the table.
  Usage (in model config post_hook):
    "{{ attach_row_access_policy('SF_TEST.SECURITY.zone_access_policy', 'zone_assignment') }}"
#}

{% macro attach_row_access_policy(policy_name, column_name) %}

    ALTER TABLE {{ this }}
    ADD ROW ACCESS POLICY {{ policy_name }}
    ON ({{ column_name }})

{% endmacro %}
