{% snapshot snp_product_pricing_history %}

{{
    config(
        target_schema = 'snapshots',
        strategy      = 'check',
        unique_key    = 'ticket_id',
        check_cols    = [
            'price', 'includes_fast_pass', 'includes_vip_benefits',
            'fear_level', 'duration_minutes'
        ]
    )
}}

select * from {{ ref('stg_park_assets__ticket_types') }}

{% endsnapshot %}
