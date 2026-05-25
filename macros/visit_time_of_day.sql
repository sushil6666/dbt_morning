{#
  visit_time_of_day(hour_column)
  Classifies a 0-23 visit hour into a named time slot.
  Shared across fct_all_ticket_sales and agg_house_profitability_by_time.
  Changing slot boundaries here updates both models automatically.
#}

{% macro visit_time_of_day(hour_column) %}

    CASE
        WHEN {{ hour_column }} BETWEEN 0  AND 11 THEN 'Morning'
        WHEN {{ hour_column }} BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN {{ hour_column }} BETWEEN 18 AND 20 THEN 'Evening'
        ELSE 'Night'
    END

{% endmacro %}
