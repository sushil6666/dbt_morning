{{ config(
    materialized='view',
    tags=['macro_demo', 'demo_31', 'variables']
) }}

/*
  demo_31_var_dev_limit
  ---------------------
  Real-world pattern: environment-aware row capping for fast dev iteration.

  On a prod-size dataset, full-table joins are slow during local development.
  A `dev_row_limit` var caps the result set in non-prod environments so
  engineers get sub-second previews without a separate dev seed or mock.

    No cap (prod / default):
      dbt run --select demo_31_var_dev_limit

    Fast dev iteration (500 rows):
      dbt run --vars '{"dev_row_limit": 500}' --select demo_31_var_dev_limit

    CI slim run (100 rows):
      dbt run --vars '{"dev_row_limit": 100}' --select demo_31_var_dev_limit

  CONVENTION:
    Never set dev_row_limit in dbt_project.yml — that would accidentally
    cap prod runs. Set it only in developer-local profiles.yml overrides
    or in CI job step env vars. The default is none (no limit).

  WHY THIS BEATS A SEPARATE DEV SEED:
    Seeds go stale. A row-limited var always samples live data, so schema
    changes and new columns surface immediately without seed maintenance.
*/

{% set row_limit = var('dev_row_limit', none) %}

select
    v.customer_id,
    c.loyalty_tier,
    c.customer_value_segment,
    c.age_group,
    v.visit_date,
    v.ticket_type,
    v.total_visit_spend,
    v.avg_rating

from {{ ref('fct_visits') }}     v
inner join {{ ref('dim_customers') }} c
    on v.customer_id = c.customer_id

{% if row_limit is not none %}
limit {{ row_limit }}
{% endif %}
