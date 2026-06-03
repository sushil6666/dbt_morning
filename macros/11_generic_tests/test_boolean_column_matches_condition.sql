{% test boolean_column_matches_condition(model, column_name, true_condition) %}

with validation_errors as (
    select
        *
    from {{ model }}
    where coalesce({{ column_name }}, false) != coalesce(({{ true_condition }}), false)
)

select *
from validation_errors

{% endtest %}
