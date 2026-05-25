{{ config(
    materialized='view',
    tags=['macro_demo', 'demo_10']
) }}

{#
  Toggle between two revenue calculation approaches with a feature flag.
  New pricing: final_price * 1.10  (includes 10% service fee)
  Old pricing: final_price          (raw ticket price only)
  Activate new logic: dbt run --vars '{"use_new_pricing_model": true}' --select demo_10_feature_flag
#}

SELECT
    ticket_id,
    customer_id,
    visit_date,
    ticket_type,
    final_price,
    {% if feature_flag('use_new_pricing_model') %}
        ROUND(final_price * 1.10, 2) AS revenue
    {% else %}
        final_price                  AS revenue
    {% endif %}
FROM {{ ref('stg_sales__tickets') }}
