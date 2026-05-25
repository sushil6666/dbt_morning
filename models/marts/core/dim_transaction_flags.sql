{{ config(materialized='table') }}

-- Junk dimension: deduplicated combinations of low-cardinality transaction flags
-- from fct_all_ticket_sales. Avoids adding multiple boolean/category columns
-- directly to the fact table.

with flag_combos as (
    select distinct
        purchase_channel,
        is_online,
        discount_category,
        same_day_visit,
        advance_purchase,
        visit_time_category,
        business_season
    from {{ ref('fct_all_ticket_sales') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['purchase_channel', 'is_online', 'discount_category', 'same_day_visit', 'advance_purchase', 'visit_time_category', 'business_season']) }} as transaction_flag_key,

    purchase_channel,
    is_online,
    discount_category,
    same_day_visit,
    advance_purchase,
    visit_time_category,
    business_season,

    purchase_channel
        || ' | ' || iff(is_online, 'online', 'offline')
        || ' | ' || coalesce(discount_category, 'no_discount')
        || ' | ' || iff(same_day_visit, 'same_day', 'advance')
        || ' | ' || visit_time_category
        || ' | ' || business_season         as flag_combo_label

from flag_combos
