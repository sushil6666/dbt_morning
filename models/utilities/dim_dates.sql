{{ config(materialized='table') }}

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
    date_day::date                                                          as date_day,
    year(date_day)                                                          as year,
    year(date_day)                                                          as year_number,
    month(date_day)                                                         as month_number,
    monthname(date_day)                                                     as month_name,
    day(date_day)                                                           as day_number,
    dayofweek(date_day)                                                     as day_of_week_number,
    dayname(date_day)                                                       as day_of_week,
    quarter(date_day)                                                       as quarter,

    case
        when dayofweek(date_day) in (0, 6) then true
        else false
    end                                                                     as is_weekend,

    -- Halloween flags
    case
        when month(date_day) = 10 and day(date_day) = 31 then true
        else false
    end                                                                     as is_halloween,

    -- Positive = days until Oct 31, negative = days since Oct 31 (same year)
    datediff(
        'day',
        date_day::date,
        date_from_parts(year(date_day), 10, 31)
    )                                                                       as days_to_halloween,

    case
        when month(date_day) in (10, 11)    then 'Halloween Season'
        when month(date_day) in (6, 7, 8)   then 'Summer'
        when month(date_day) in (12, 1, 2)  then 'Winter'
        when month(date_day) in (3, 4, 5)   then 'Spring'
        else 'Fall'
    end                                                                     as business_season

from date_spine
