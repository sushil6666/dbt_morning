{{ config(materialized='table') }}

with employees as (
    select * from {{ ref('stg_employees__employees') }}
),

managers as (
    select
        employee_id,
        full_name as manager_name
    from {{ ref('stg_employees__employees') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['e.employee_id']) }} as employee_key,
    e.employee_id,
    e.full_name,
    e.department,
    e.role,
    e.hire_date,
    e.hourly_rate,
    round(e.hourly_rate * 40 * 52, 2)              as estimated_annual_salary,
    e.manager_id,
    m.manager_name,
    e.is_active,
    e.zone_assignment,
    datediff('year', e.hire_date, current_date())  as years_of_service
from employees e
left join managers m on e.manager_id = m.employee_id
