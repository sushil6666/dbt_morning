{% snapshot snp_rides %}

{{
    config(
        target_schema = 'snapshots',
        strategy      = 'timestamp',
        unique_key    = 'ride_id',
        updated_at    = 'updated_at'
    )
}}

select * from {{ ref('stg_park_assets__rides') }}

{% endsnapshot %}
