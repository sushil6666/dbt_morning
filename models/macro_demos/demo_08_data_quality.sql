{{ config(
    materialized='view',
    tags=['macro_demo', 'demo_08']
) }}

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    phone,
    is_vip_member,
    {{ data_quality_score([
        {'col': 'customer_id', 'type': 'not_null',   'weight': 4},
        {'col': 'email',       'type': 'valid_email', 'weight': 3},
        {'col': 'first_name',  'type': 'not_null',   'weight': 2},
        {'col': 'phone',       'type': 'not_null',   'weight': 1}
    ]) }} AS dq_score
FROM {{ ref('stg_customer_data__customers') }}
