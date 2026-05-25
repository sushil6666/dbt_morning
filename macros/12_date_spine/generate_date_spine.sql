{#
  generate_date_spine(start_date, end_date)
  Generates a complete date series between two dates — cross-adapter.
  Snowflake  → TABLE(GENERATOR) + DATEADD
  Postgres   → GENERATE_SERIES
  BigQuery   → UNNEST(GENERATE_DATE_ARRAY)
  DuckDB     → GENERATE_SERIES (cast to date)
  Usage: {{ generate_date_spine('2023-01-01', '2023-12-31') }}
         Can also accept var()-driven dates.
#}

{% macro generate_date_spine(start_date, end_date) %}

    {% if target.type == 'snowflake' %}

        SELECT
            DATEADD(
                day,
                SEQ4(),
                '{{ start_date }}'::DATE
            ) AS spine_date
        FROM TABLE(GENERATOR(ROWCOUNT => DATEDIFF('day', '{{ start_date }}'::DATE, '{{ end_date }}'::DATE) + 1))

    {% elif target.type in ('postgres', 'redshift') %}

        SELECT
            GENERATE_SERIES(
                '{{ start_date }}'::DATE,
                '{{ end_date }}'::DATE,
                INTERVAL '1 day'
            )::DATE AS spine_date

    {% elif target.type == 'bigquery' %}

        SELECT spine_date
        FROM UNNEST(
            GENERATE_DATE_ARRAY('{{ start_date }}', '{{ end_date }}', INTERVAL 1 DAY)
        ) AS spine_date

    {% elif target.type == 'duckdb' %}

        SELECT
            ('{{ start_date }}'::DATE + INTERVAL (n) DAY)::DATE AS spine_date
        FROM GENERATE_SERIES(0, DATEDIFF('day', '{{ start_date }}'::DATE, '{{ end_date }}'::DATE)) AS t(n)

    {% else %}

        SELECT
            DATEADD(day, SEQ4(), '{{ start_date }}'::DATE) AS spine_date
        FROM TABLE(GENERATOR(ROWCOUNT => DATEDIFF('day', '{{ start_date }}'::DATE, '{{ end_date }}'::DATE) + 1))

    {% endif %}

{% endmacro %}
