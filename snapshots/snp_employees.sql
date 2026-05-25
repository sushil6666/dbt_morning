{% snapshot snp_employees %}

{{
    config(
        target_schema = 'snapshots',
        strategy      = 'timestamp',
        unique_key    = 'employee_id',
        updated_at    = 'updated_at'
    )
}}

select * from {{ ref('stg_employees__employees') }}

{% endsnapshot %}
