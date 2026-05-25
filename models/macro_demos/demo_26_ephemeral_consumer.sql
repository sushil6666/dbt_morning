{{
    config(
        materialized = 'view',
        tags         = ['macro_demo', 'demo_26', 'ephemeral']
    )
}}

{#
  demo_26_ephemeral_consumer
  -----------------------------------------------------------------------
  This model consumes demo_26_ephemeral_base, which is ephemeral.

  AT COMPILE TIME dbt replaces {{ ref('demo_26_ephemeral_base') }} with
  the full SQL of that model as a CTE, so the compiled output looks like:

    WITH demo_26_ephemeral_base__dbt_cte AS (
        -- <full SQL of demo_26_ephemeral_base injected here>
    ),
    final AS (
        SELECT ...
        FROM demo_26_ephemeral_base__dbt_cte
        ...
    )
    SELECT * FROM final;

  No separate CREATE TABLE / CREATE VIEW is ever issued for the base model.
  Run:
    dbt compile -s demo_26_ephemeral_consumer
  and open target/compiled/…/demo_26_ephemeral_consumer.sql to verify.
#}

WITH final AS (

    SELECT
        revenue_category,
        spending_tier,
        payment_method,
        COUNT(*)                              AS transaction_count,
        SUM(total_amount)                     AS total_revenue,
        ROUND(AVG(total_amount), 2)           AS avg_transaction_value,
        SUM(CASE WHEN is_high_value THEN 1 ELSE 0 END) AS high_value_count

    FROM {{ ref('demo_26_ephemeral_base') }}   -- <-- inlined as CTE at compile time

    GROUP BY
        revenue_category,
        spending_tier,
        payment_method

)

SELECT
    revenue_category,
    spending_tier,
    payment_method,
    transaction_count,
    total_revenue,
    avg_transaction_value,
    high_value_count,
    ROUND(
        100.0 * high_value_count / NULLIF(transaction_count, 0),
        1
    )                                         AS high_value_pct
FROM final
ORDER BY
    revenue_category,
    total_revenue DESC
