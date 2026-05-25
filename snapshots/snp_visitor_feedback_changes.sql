{% snapshot snp_visitor_feedback_changes %}

{{
    config(
        target_schema = 'snapshots',
        strategy      = 'check',
        unique_key    = 'feedback_id',
        check_cols    = ['satisfaction_rating', 'would_recommend']
    )
}}

select * from {{ ref('stg_feedback__haunted_visitor_feedback') }}

{% endsnapshot %}
