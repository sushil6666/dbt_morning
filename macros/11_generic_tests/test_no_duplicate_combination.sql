{% test no_duplicate_combination(model, key_columns) %}

with duplicates as (
    select
        {% for col in key_columns %}
        {{ col }}{% if not loop.last %}, {% endif %}
        {% endfor %},
        count(*) as row_count
    from {{ model }}
    group by
        {% for col in key_columns %}
        {{ col }}{% if not loop.last %}, {% endif %}
        {% endfor %}
    having count(*) > 1
)

select *
from duplicates

{% endtest %}
