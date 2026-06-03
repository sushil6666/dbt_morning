{{ config(
    materialized='view',
    tags=['macro_demo', 'demo_11']
) }}

{#
  The custom generic tests (`valid_ticket_types`, `rating_in_range`) are defined in
  `macros/11_generic_tests/test_valid_ticket_types.sql` and
  `macros/11_generic_tests/test_rating_in_range.sql`, and are referenced from
  `models/macro_demos/schema_demo_11_generic_tests.yml`.
  Run: dbt test --select demo_11_generic_tests
#}

SELECT
    t.ticket_id,
    t.customer_id,
    t.visit_date,
    t.ticket_type,
    v.rating AS satisfaction_rating
FROM {{ ref('stg_sales__tickets') }} t
LEFT JOIN {{ ref('stg_feedback__visitor_feedback') }} v
    ON t.customer_id = v.customer_id
    AND t.visit_date  = v.visit_date
