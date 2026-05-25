{#
  pre_swap_clone() / post_swap_table(staging_table)
  Clone-and-swap pattern for zero-downtime mart rebuilds.
  pre_swap_clone  → backs up the existing table before the build starts
  post_swap_table → atomically swaps staging into production after build succeeds
  BI dashboards see no downtime — the swap is instantaneous from their perspective.
  Usage in model config:
    pre_hook="{{ pre_swap_clone() }}"
    post_hook="{{ post_swap_table(this.schema ~ '.my_model_staging') }}"
#}

{% macro pre_swap_clone() %}

    {% set backup = this.schema ~ '.' ~ this.name ~ '_backup' %}
    CREATE OR REPLACE TABLE {{ backup }}
    CLONE {{ this }}

{% endmacro %}


{% macro post_swap_table(staging_table) %}

    ALTER TABLE {{ staging_table }} SWAP WITH {{ this }};
    DROP TABLE IF EXISTS {{ staging_table }}_backup

{% endmacro %}
