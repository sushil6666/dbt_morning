{{
    config(
        materialized = 'ephemeral',
        tags         = ['macro_demo', 'demo_26', 'ephemeral']
    )
}}

{#
  demo_26_ephemeral_base
  -----------------------------------------------------------------------
  MATERIALIZATION: ephemeral

  An ephemeral model NEVER creates a database object (no table, no view).
  Instead, dbt injects its SQL as a CTE directly inside every downstream
  model that calls {{ ref('demo_26_ephemeral_base') }}.

  WHY EPHEMERAL?
    Use ephemeral when you want to:
      • Share a reusable transformation without persisting intermediate data.
      • Keep the warehouse clean — zero extra objects created.
      • Avoid the overhead of a separate query execution step.

  TRADE-OFFS:
    ✗  Cannot be queried directly in Snowflake (no physical object exists).
    ✗  SQL is duplicated in every consumer — avoid for very large/expensive
       transformations that are referenced by many downstream models
       (use a view or table instead to materialise once).
    ✓  Zero storage cost.
    ✓  Simplifies DAG — intermediate nodes are collapsed into consumers.

  THIS MODEL:
    Enriches raw sales transactions with:
      - Spending tier label       (low / mid / high)
      - Revenue category          (Food & Bev, Merchandise, Ticket, Other)
      - A Boolean flag for high-value transactions (>= $100)
    The enriched CTE is inlined into demo_26_ephemeral_consumer at
    compile time — run `dbt compile -s demo_26_ephemeral_consumer`
    and inspect target/compiled/ to see the injected SQL.
#}

WITH source AS (

    SELECT * FROM {{ ref('stg_sales_transactions__sales_transactions') }}

),

enriched AS (

    SELECT
        transaction_id,
        customer_id,
        visit_date,
        category,
        item_name,
        quantity,
        unit_price,
        total_amount,
        payment_method,
        location,

        -- Spending tier derived from total_amount
        CASE
            WHEN total_amount >= 100 THEN 'high'
            WHEN total_amount >= 40  THEN 'mid'
            ELSE                          'low'
        END                                          AS spending_tier,

        -- Broad revenue category
        CASE
            WHEN category ILIKE '%food%'
              OR category ILIKE '%bev%'   THEN 'Food & Beverage'
            WHEN category ILIKE '%merch%' THEN 'Merchandise'
            WHEN category ILIKE '%ticket%'THEN 'Ticket'
            ELSE                               'Other'
        END                                          AS revenue_category,

        -- Flag high-value single transactions
        (total_amount >= 100)                        AS is_high_value

    FROM source

)

SELECT * FROM enriched
