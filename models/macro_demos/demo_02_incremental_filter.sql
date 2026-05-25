{{ config(
    materialized='incremental',
    unique_key='ticket_id',
    tags=['macro_demo', 'demo_02']
) }}

SELECT
    ticket_id,
    customer_id,
    visit_date,
    ticket_type,
    base_price,
    final_price
FROM {{ ref('stg_sales__tickets') }}

{% if is_incremental() %}
WHERE {{ incremental_filter('visit_date', dev_lookback_days=3) }}
{% endif %}
