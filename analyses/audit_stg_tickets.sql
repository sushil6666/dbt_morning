{{
    audit_helper.compare_relations(
        a_relation     = ref('stg_sales__tickets'),
        b_relation     = source('raw', 'raw_tickets'),
        primary_key    = 'ticket_id',
        exclude_columns = ['is_discounted']
    )
}}
