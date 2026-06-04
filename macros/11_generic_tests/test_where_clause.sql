{% test where_clause(model, row_condition, failure_condition) %}

with scoped_rows as (
    select
        *
    from {{ model }}
    where {{ row_condition }}
),
validation_errors as (
    select
        *
    from scoped_rows
    where {{ failure_condition }}
)

select *
from validation_errors

{% endtest %}

