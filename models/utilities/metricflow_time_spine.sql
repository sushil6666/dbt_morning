{{ config(materialized='table') }}

-- MetricFlow requires a time spine model with a single date_day column.
-- Used by dbt Semantic Layer / MetricFlow for time-series metric definitions.

with date_spine as (
    {{
        dbt_utils.date_spine(
            datepart   = "day",
            start_date = "cast('" ~ var('date_spine_start') ~ "' as date)",
            end_date   = "cast('" ~ var('date_spine_end')   ~ "' as date)"
        )
    }}
)

select
    date_day::date as date_day
from date_spine
