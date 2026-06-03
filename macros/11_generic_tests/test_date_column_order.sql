{% test date_column_order(model, earlier_column, later_column, allow_equal=true) %}

with validation_errors as (
    select
        {{ earlier_column }} as earlier_value,
        {{ later_column }} as later_value
    from {{ model }}
    where {{ earlier_column }} is not null
      and {{ later_column }} is not null
      and (
        {% if allow_equal %}
        {{ earlier_column }} > {{ later_column }}
        {% else %}
        {{ earlier_column }} >= {{ later_column }}
        {% endif %}
      )
)

select *
from validation_errors

{% endtest %}
