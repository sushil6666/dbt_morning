{#
  test_valid_ticket_types(model, column_name, valid_types)
  Generic test: fails if any row contains a ticket_type not in the allowed list.
  Usage in schema.yml:
    - name: ticket_type
      tests:
        - valid_ticket_types:
            valid_types: ['general', 'vip', 'group', 'child']

  test_rating_in_range(model, column_name, min_val, max_val)
  Generic test: fails if satisfaction_rating falls outside the expected numeric range.
  Usage in schema.yml:
    - name: satisfaction_rating
      tests:
        - rating_in_range:
            min_val: 1
            max_val: 5
#}

{% test valid_ticket_types(model, column_name, valid_types) %}

    SELECT {{ column_name }}
    FROM {{ model }}
    WHERE {{ column_name }} NOT IN (
        '{{ valid_types | join("', '") }}'
    )

{% endtest %}


{% test rating_in_range(model, column_name, min_val, max_val) %}

    SELECT {{ column_name }}
    FROM {{ model }}
    WHERE {{ column_name }} < {{ min_val }}
       OR {{ column_name }} > {{ max_val }}

{% endtest %}
