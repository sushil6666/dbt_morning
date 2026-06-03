{% test require_column_when(model, column_name, condition) %}

with validation_errors as (
    select
        *
    from {{ model }}
    where {{ condition }}
      and {{ column_name }} is null
)

select *
from validation_errors

{% endtest %}
