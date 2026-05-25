-- Asserts that no ticket has a negative final price.
-- final_price should always be >= 0 even after discounts are applied.

select
    ticket_id,
    base_price,
    discount_amount,
    final_price
from {{ source('raw', 'raw_tickets') }}
where final_price < 0
