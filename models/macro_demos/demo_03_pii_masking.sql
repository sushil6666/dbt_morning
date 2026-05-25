{#{ config(
    materialized='view',
    tags=['macro_demo', 'demo_03']
) }#}

SELECT
    customer_id,
    first_name,
    last_name,
    {{ mask_pii('email', 'hash') }}    AS email_masked,
    {{ mask_pii('phone', 'partial') }} AS phone_masked,
    {{ mask_pii('address', 'redact') }} AS address_masked,
    age,
    is_vip_member
FROM {{ ref('stg_customer_data__customers') }}
