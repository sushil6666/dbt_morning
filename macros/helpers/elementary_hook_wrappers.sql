{% macro safe_elementary_on_run_start() %}
    {% if execute and flags.WHICH in ['freshness', 'source freshness', 'source'] %}
        {{ return('') }}
    {% endif %}

    {{ return(elementary.on_run_start()) }}
{% endmacro %}

{% macro safe_elementary_on_run_end() %}
    {% if execute and flags.WHICH in ['freshness', 'source freshness', 'source'] %}
        {{ return('') }}
    {% endif %}

    {{ return(elementary.on_run_end()) }}
{% endmacro %}

