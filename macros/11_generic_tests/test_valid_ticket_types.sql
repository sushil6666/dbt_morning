{% test valid_ticket_types(model, column_name, valid_types) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} not in (
    '{{ valid_types | join("', '") }}'
)

{% endtest %}
