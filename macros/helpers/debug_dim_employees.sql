{% macro debug_dim_employees() %}
    {% set query %}
        select employee_id, count(*) as cnt 
        from SF_TEST.marts.dim_employees 
        group by employee_id 
        having count(*) > 1 
        limit 5
    {% endset %}
    {% set results = run_query(query) %}
    {% if execute %}
        {% for row in results %}
            {{ log('Duplicate employee_id: ' ~ row[0] ~ ', count: ' ~ row[1], info=True) }}
        {% endfor %}
        {% if results | length == 0 %}
            {{ log('No duplicates found!', info=True) }}
        {% endif %}
    {% endif %}
{% endmacro %}
