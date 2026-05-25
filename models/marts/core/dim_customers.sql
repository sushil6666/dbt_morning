{{ config(
    materialized='table',
    post_hook="{{ apply_constraints(primary_key='customer_id') }}"
) }}

with customers as (
    select * from {{ ref('stg_customer_data__customers') }}
),

state_names as (
    select $1::varchar as state_code, $2::varchar as state_name
    from (values
        ('AL','Alabama'),    ('AK','Alaska'),      ('AZ','Arizona'),    ('AR','Arkansas'),
        ('CA','California'), ('CO','Colorado'),    ('CT','Connecticut'),('DE','Delaware'),
        ('FL','Florida'),    ('GA','Georgia'),     ('HI','Hawaii'),     ('ID','Idaho'),
        ('IL','Illinois'),   ('IN','Indiana'),     ('IA','Iowa'),       ('KS','Kansas'),
        ('KY','Kentucky'),   ('LA','Louisiana'),   ('ME','Maine'),      ('MD','Maryland'),
        ('MA','Massachusetts'),('MI','Michigan'),  ('MN','Minnesota'),  ('MS','Mississippi'),
        ('MO','Missouri'),   ('MT','Montana'),     ('NE','Nebraska'),   ('NV','Nevada'),
        ('NH','New Hampshire'),('NJ','New Jersey'),('NM','New Mexico'), ('NY','New York'),
        ('NC','North Carolina'),('ND','North Dakota'),('OH','Ohio'),    ('OK','Oklahoma'),
        ('OR','Oregon'),     ('PA','Pennsylvania'),('RI','Rhode Island'),('SC','South Carolina'),
        ('SD','South Dakota'),('TN','Tennessee'),  ('TX','Texas'),      ('UT','Utah'),
        ('VT','Vermont'),    ('VA','Virginia'),    ('WA','Washington'), ('WV','West Virginia'),
        ('WI','Wisconsin'),  ('WY','Wyoming')
    )
),

enriched as (
    select
        -- Identity
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        regexp_like(
            c.email,
            '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$'
        )                                                           as is_valid_email,
        c.phone,
        c.address,
        c.city,
        c.state,
        coalesce(s.state_name, c.state)                             as state_name,
        c.zip_code,
        c.age,
        c.gender,

        -- Membership & preferences
        c.is_vip_member,
        c.marketing_opt_in,
        c.preferred_scare_level,
        c.loyalty_points,
        c.registration_date,

        -- Calculated segments
        case
            when c.age < 18                 then 'Under 18'
            when c.age between 18 and 24    then '18-24'
            when c.age between 25 and 34    then '25-34'
            when c.age between 35 and 44    then '35-44'
            when c.age between 45 and 54    then '45-54'
            else '55+'
        end                                                         as age_group,

        case
            when c.loyalty_points >= 1000   then 'Gold'
            when c.loyalty_points >= 500    then 'Silver'
            else 'Bronze'
        end                                                         as loyalty_tier,

        case
            when c.is_vip_member and c.loyalty_points >= 1000      then 'High Value'
            when c.is_vip_member or  c.loyalty_points >= 500       then 'Mid Value'
            else 'Standard'
        end                                                         as customer_value_segment,

        case
            when datediff('month', c.registration_date, current_date()) <= 3   then 'New'
            when datediff('month', c.registration_date, current_date()) <= 12  then 'Growing'
            else 'Established'
        end                                                         as customer_lifecycle_stage,

        case
            when c.loyalty_points < 100
                and datediff('month', c.registration_date, current_date()) > 6
                                            then 'High'
            when c.loyalty_points < 300     then 'Medium'
            else 'Low'
        end                                                         as retention_risk_level,

        case
            when c.is_vip_member = false
                and c.loyalty_points >= 400                         then 'VIP Upgrade'
            when c.marketing_opt_in = true
                and c.is_vip_member = false                         then 'Premium Pass'
            else 'None'
        end                                                         as upsell_opportunity,

        c.created_at,
        c.updated_at

    from customers c
    left join state_names s on upper(c.state) = s.state_code
)

select * from enriched
