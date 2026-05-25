{% snapshot snp_ticket_sales_history %}

{{
    config(
        target_schema = 'snapshots',
        strategy      = 'check',
        unique_key    = 'sale_id',
        check_cols    = ['ticket_price', 'discount_percent', 'payment_method']
    )
}}

with online as (
    select * from {{ ref('stg_sales__ticket_sales_online') }}
),

physical as (
    select * from {{ ref('stg_sales__ticket_sales_physical') }}
)

select * from online
union all
select * from physical

{% endsnapshot %}
