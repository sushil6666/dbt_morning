{#
  incremental_filter(timestamp_col, dev_lookback_days=3)
  Generates environment-aware WHERE clause for incremental models.
  dev  → scans only last N days (cheap, fast testing)
  prod → scans since the last loaded timestamp (correct watermark)
  Usage: WHERE {{ incremental_filter('visit_date') }}
#}

{% macro incremental_filter(timestamp_col, dev_lookback_days=3) %}

    {% if is_incremental() %}
        {% if target.name == 'dev' %}
            {{ timestamp_col }} >= DATEADD(
                day,
                -{{ var('dev_lookback_days', dev_lookback_days) }},
                CURRENT_DATE()
            )
        {% else %}
            {{ timestamp_col }} > (
                SELECT MAX({{ timestamp_col }}) FROM {{ this }}
            )
        {% endif %}
    {% endif %}

{% endmacro %}
