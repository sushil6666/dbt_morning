{% snapshot snp_customers %}

{{
    config(
        target_schema = 'snapshots',
        strategy      = 'check',
        unique_key    = 'customer_id',
        check_cols              = [
            'first_name', 'last_name', 'email', 'phone',
            'address', 'city', 'state', 'zip_code',
            'is_vip_member', 'marketing_opt_in', 'loyalty_points'
        ],
        invalidate_hard_deletes = true
    )
}}

select * from {{ ref('stg_customer_data__customers') }}

{% endsnapshot %}
