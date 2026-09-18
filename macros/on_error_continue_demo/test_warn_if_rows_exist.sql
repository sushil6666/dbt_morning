{% test warn_if_rows_exist(model) %}

select *
from {{ model }}

{% endtest %}
