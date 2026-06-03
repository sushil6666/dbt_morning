{% test rating_in_range(model, column_name, min_val, max_val) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} < {{ min_val }}
   or {{ column_name }} > {{ max_val }}

{% endtest %}
