{{ config(
    materialized='view',
    tags=['macro_demo', 'demo_29', 'variables']
) }}

/*
  demo_29_var_spend_tiers
  -----------------------
  Real-world pattern: business threshold variables for spend segmentation.

  Finance teams review and adjust tier boundaries quarterly. Instead of a
  code change, they live in dbt_project.yml and can be overridden per run:

    Production defaults:
      spend_tier_high: 300   (>= $300 → High spender)
      spend_tier_mid:  100   (>= $100 → Mid spender, else Low)

    Override for one-off analysis:
      dbt run --vars '{"spend_tier_high": 400, "spend_tier_mid": 150}' \
              --select demo_29_var_spend_tiers

  WHY VAR NOT HARDCODE:
    Tier thresholds are business decisions, not engineering ones. Encoding
    them as vars moves ownership to the analyst / finance team and avoids
    accidental divergence between the dashboard definition and the SQL.

  EMITTED COLUMNS:
    tier_high_threshold and tier_mid_threshold are stamped onto every row
    so BI tools can show "High (>=$300)" in labels without hardcoding the
    boundary in the report itself.
*/

{% set tier_high = var('spend_tier_high', 300) %}
{% set tier_mid  = var('spend_tier_mid',  100) %}

select
    customer_id,
    visit_date,
    ticket_type,
    total_visit_spend,
    avg_rating,

    case
        when total_visit_spend >= {{ tier_high }} then 'High'
        when total_visit_spend >= {{ tier_mid  }} then 'Mid'
        else                                           'Low'
    end                                         as spend_tier,

    {{ tier_high }}                             as tier_high_threshold,
    {{ tier_mid  }}                             as tier_mid_threshold

from {{ ref('fct_visits') }}
where total_visit_spend is not null
