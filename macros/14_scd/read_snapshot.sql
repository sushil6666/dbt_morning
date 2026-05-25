{#
  read_current_snapshot(snapshot_relation)
  Returns only the currently-active rows from a dbt snapshot (dbt_valid_to IS NULL).
  Keeps downstream models clean — they don't need to remember the SCD filter.
  Usage: FROM {{ read_current_snapshot(ref('snp_customers')) }}

  scd_metadata_columns()
  Emits the four standard dbt snapshot audit columns for SELECT lists.
  Usage: SELECT customer_id, {{ scd_metadata_columns() }} FROM ...
#}

{% macro read_current_snapshot(snapshot_relation) %}

    (
        SELECT *
        FROM {{ snapshot_relation }}
        WHERE dbt_valid_to IS NULL
    )

{% endmacro %}


{% macro scd_metadata_columns() %}

    dbt_scd_id,
    dbt_updated_at,
    dbt_valid_from,
    dbt_valid_to,
    CASE
        WHEN dbt_valid_to IS NULL THEN TRUE
        ELSE FALSE
    END AS is_current_record

{% endmacro %}
