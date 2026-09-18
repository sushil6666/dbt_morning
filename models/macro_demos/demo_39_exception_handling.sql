{{ config(
    materialized='view',
    tags=['macro_demo', 'demo_39', 'exceptions']
) }}

/*
  Demonstrates dbt's exceptions namespace with three modes:
    safe  - builds normally (default)
    warn  - emits a Jinja warning and still builds successfully
    error - raises a compiler error intentionally

  Examples:
    dbt build --select demo_39_exception_handling
    dbt build --select demo_39_exception_handling --vars '{"demo_39_exception_mode": "warn"}'
    dbt build --select demo_39_exception_handling --vars '{"demo_39_exception_mode": "error"}'
*/

{% set exception_mode = var('demo_39_exception_mode', 'safe') | lower %}

{% if execute %}
    {% if exception_mode == 'warn' %}
        {% do exceptions.warn('Demo 39 warning: the model will continue and build successfully.') %}
    {% elif exception_mode == 'error' %}
        {{ exceptions.raise_compiler_error('Demo 39 error: intentional compiler exception.') }}
    {% elif exception_mode != 'safe' %}
        {{ exceptions.raise_compiler_error(
            "demo_39_exception_mode must be one of: safe, warn, error. Got: " ~ exception_mode
        ) }}
    {% endif %}
{% endif %}

select
    1 as scenario_id,
    'exception_handling_reference' as scenario_name,
    '{{ exception_mode }}' as demo_status
