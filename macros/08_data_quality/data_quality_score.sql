{#
  data_quality_score(checks)
  Generates a 0-100 DQ confidence score per row based on weighted column checks.
  checks = list of dicts: {col, type, weight}
  check types: 'not_null' | 'positive' | 'valid_email'
  Usage:
    {{ data_quality_score([
        {'col': 'customer_id', 'type': 'not_null',   'weight': 4},
        {'col': 'email',       'type': 'valid_email', 'weight': 3},
        {'col': 'final_price', 'type': 'positive',   'weight': 3}
    ]) }} AS dq_score
#}

{% macro data_quality_score(checks) %}

    {% set total_weight = checks | map(attribute='weight') | sum %}
    ROUND(
        (0
        {% for check in checks %}
            {% if check.type == 'not_null' %}
            + (CASE WHEN {{ check.col }} IS NOT NULL
               THEN {{ check.weight }} ELSE 0 END)
            {% elif check.type == 'positive' %}
            + (CASE WHEN {{ check.col }} > 0
               THEN {{ check.weight }} ELSE 0 END)
            {% elif check.type == 'valid_email' %}
            + (CASE WHEN {{ check.col }} REGEXP '[^@]+@[^.]+\..+'
               THEN {{ check.weight }} ELSE 0 END)
            {% endif %}
        {% endfor %}
        ) * 100.0 / {{ total_weight }}, 1
    )

{% endmacro %}
