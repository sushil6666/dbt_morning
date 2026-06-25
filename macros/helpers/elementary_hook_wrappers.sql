{% macro safe_elementary_on_run_start() %}
    {% if execute and flags.WHICH in ['freshness', 'source freshness', 'source'] %}
        {{ return('') }}
    {% endif %}

    {% if not execute %}
        {{ return('') }}
    {% endif %}

    {% set current_db_query %}
        select current_database()
    {% endset %}

    {% set current_db_result = run_query(current_db_query) %}
    {% set current_db = current_db_result.columns[0].values()[0] if current_db_result is not none else none %}

    {% if current_db is none %}
        {{ log("Skipping elementary on-run-start hook because current_database() returned no value", info=true) }}
        {{ return('') }}
    {% endif %}

    {% if target.database is not none and current_db | upper != target.database | upper %}
        {{ log("Skipping elementary on-run-start hook because current database is " ~ current_db ~ " and target database is " ~ target.database, info=true) }}
        {{ return('') }}
    {% endif %}

    {{ return(elementary.on_run_start()) }}
{% endmacro %}

{% macro safe_elementary_on_run_end() %}
    {% if execute and flags.WHICH in ['freshness', 'source freshness', 'source'] %}
        {{ return('') }}
    {% endif %}

    {% if not execute %}
        {{ return('') }}
    {% endif %}

    {% set current_db_query %}
        select current_database()
    {% endset %}

    {% set current_db_result = run_query(current_db_query) %}
    {% set current_db = current_db_result.columns[0].values()[0] if current_db_result is not none else none %}

    {% if current_db is none %}
        {{ log("Skipping elementary on-run-end hook because current_database() returned no value", info=true) }}
        {{ return('') }}
    {% endif %}

    {% if target.database is not none and current_db | upper != target.database | upper %}
        {{ log("Skipping elementary on-run-end hook because current database is " ~ current_db ~ " and target database is " ~ target.database, info=true) }}
        {{ return('') }}
    {% endif %}

    {{ return(elementary.on_run_end()) }}
{% endmacro %}
