{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_12']
) }}

{#
  Date spine joined to fct_visits to ensure every day in the season appears,
  even days with zero visits (gaps would be invisible without a spine).
  Snowflake GENERATOR requires a compile-time constant for ROWCOUNT, so we
  generate 400 rows (> any single year) and filter to the target date range.
#}

WITH spine AS (

    SELECT
        DATEADD(day, SEQ4(), '{{ var("halloween_analysis_start_date", "2023-01-01") }}'::DATE) AS spine_date
    FROM TABLE(GENERATOR(ROWCOUNT => 400))
    WHERE spine_date <= '2023-12-31'

),

daily_visits AS (

    SELECT
        visit_date,
        COUNT(*)                   AS total_visits,
        SUM(total_visit_spend)     AS total_revenue,
        AVG(avg_rating)            AS avg_rating
    FROM {{ ref('fct_visits') }}
    GROUP BY 1

)

SELECT
    s.spine_date                            AS visit_date,
    COALESCE(d.total_visits, 0)             AS total_visits,
    COALESCE(d.total_revenue, 0)            AS total_revenue,
    d.avg_rating
FROM spine s
LEFT JOIN daily_visits d
    ON s.spine_date = d.visit_date
ORDER BY 1
