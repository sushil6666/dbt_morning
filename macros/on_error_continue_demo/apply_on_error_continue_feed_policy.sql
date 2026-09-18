{% macro apply_on_error_continue_feed_policy(mode='safe') %}
    {% set normalized_mode = mode | lower %}

    {% if execute %}
        {% if normalized_mode == 'warn' %}
            {% do exceptions.warn(
                'On-error-continue payment feed alert: malformed or negative amounts were detected; the quality model will continue.'
            ) %}
        {% elif normalized_mode == 'error' %}
            {{ exceptions.raise_compiler_error(
                'On-error-continue payment feed rejected: quality policy is set to error.'
            ) }}
        {% elif normalized_mode != 'safe' %}
            {{ exceptions.raise_compiler_error(
                'on_error_continue_demo_exception_mode must be safe, warn, or error. Got: ' ~ normalized_mode
            ) }}
        {% endif %}
    {% endif %}

    {{ return('') }}
{% endmacro %}
