{{ config(materialized='view') }}

with source as (
    select * from {{ source('employees', 'employees') }}
),

renamed as (
    select
        employee_id,
        first_name,
        last_name,
        first_name || ' ' || last_name  as full_name,
        department,
        role,
        hire_date::date                 as hire_date,
        hourly_rate::numeric(10, 2)     as hourly_rate,
        manager_id,
        is_active::boolean              as is_active,
        zone_assignment,
        hire_date::timestamp            as updated_at
    from source
)

select * from renamed
