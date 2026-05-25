{#
  mask_pii(column_name, mask_type='hash')
  Masks sensitive customer columns in non-production environments.
  In dev/staging/ci: returns hash, redaction, or partial mask.
  In prod: returns the raw column unchanged.
  mask_type options: 'hash' | 'redact' | 'partial'
  Usage: {{ mask_pii('email', 'redact') }} AS email
#}

{% macro mask_pii(column_name, mask_type='hash') %}

    {% if target.name != 'prod' %}
        {% if mask_type == 'hash' %}
            SHA2(CAST({{ column_name }} AS VARCHAR), 256)
        {% elif mask_type == 'redact' %}
            '***REDACTED***'
        {% elif mask_type == 'partial' %}
            CONCAT(LEFT(CAST({{ column_name }} AS VARCHAR), 2), '****')
        {% else %}
            NULL
        {% endif %}
    {% else %}
        {{ column_name }}
    {% endif %}

{% endmacro %}
