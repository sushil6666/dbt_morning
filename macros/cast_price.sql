{#
  cast_price(column_name, precision=10, scale=2)
  Casts a price column to DECIMAL with configurable precision and scale.
  Default DECIMAL(10,2) covers standard ticket prices up to $99,999,999.99.
  Use precision=12, scale=4 for discount_amount where sub-cent accuracy matters.
#}

{% macro cast_price(column_name, precision=10, scale=2) %}

    CAST({{ column_name }} AS DECIMAL({{ precision }}, {{ scale }}))

{% endmacro %}
