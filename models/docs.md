{% docs ticket_price_definition %}
## Ticket Price Definitions

All ticket price columns across staging and mart layers follow these definitions:

- **base_price**: Face value of the ticket before any discount is applied.
- **discount_amount**: Monetary discount applied at purchase. Zero when no promo code or offer was used.
- **final_price / ticket_price**: Amount the customer actually paid — `base_price - discount_amount`. This is the primary revenue measure for ticket-related reporting.
- **discount_percent**: `(discount_amount / base_price) * 100`, rounded to 2 decimal places. Zero when base_price = 0 to avoid division by zero.

Do **not** use `base_price` for revenue reporting. Always use `final_price` or `ticket_price`.
{% enddocs %}

{% docs surrogate_key_note %}
Surrogate primary key generated using `dbt_utils.generate_surrogate_key`. This key is stable
as long as the natural key inputs do not change. Use this column for all joins between fact
tables and dimension tables. The original natural key is preserved alongside it for debugging
and source reconciliation.
{% enddocs %}

{% docs pii_warning %}
**PII — Personally Identifiable Information.**
This column contains customer data classified as confidential under the park's Data
Classification Policy. Do **not** expose this column in shared BI environments or public
dashboards. For aggregate analysis that does not require individual identity, use the
anonymised or derived equivalent column where available.
{% enddocs %}

{% docs scd2_note %}
This is a **Type 2 Slowly Changing Dimension (SCD2)** snapshot. Each change to a tracked
attribute creates a new row with:
- `dbt_valid_from` — the timestamp when this version became active
- `dbt_valid_to` — the timestamp when this version was superseded (NULL for the current row)
- `dbt_scd_id` — surrogate key unique to each historical version

To query **current state only**, filter on `dbt_valid_to IS NULL`.
To query **historical state** at a point in time, filter on
`dbt_valid_from <= <point_in_time> AND (dbt_valid_to > <point_in_time> OR dbt_valid_to IS NULL)`.
{% enddocs %}

{% docs fear_level_mapping %}
Numeric fear intensity score derived from `thrill_level`:

| thrill_level | fear_level |
|-------------|-----------|
| extreme     | 5         |
| high        | 4         |
| medium      | 3         |
| low         | 2         |
| unknown     | 3 (default) |

Used to correlate ride intensity with visitor satisfaction across haunted house analytics.
{% enddocs %}

{% docs business_season_definition %}
Business season bucket derived from the calendar month of the visit date:

| Months    | Season            |
|-----------|-------------------|
| Oct, Nov  | Halloween Season  |
| Jun–Aug   | Summer            |
| Dec–Feb   | Winter            |
| Mar–May   | Spring            |
| Sep       | Fall              |

Used for seasonal revenue analysis. Halloween Season is the park's peak revenue period.
{% enddocs %}

{% docs loyalty_points_derivation %}
Loyalty points are derived from the customer's membership tier at time of staging:

| membership_type | loyalty_points |
|----------------|----------------|
| platinum        | 1,000          |
| gold            | 500            |
| silver          | 250            |
| standard / vip  | 100            |

These are **static seed values** based on membership tier, not a running accumulation of
individual visit transactions. For a transactional loyalty calculation, join to
`fct_all_ticket_sales` or `fct_visits`.
{% enddocs %}

{% docs discount_category_definition %}
Bucketed discount tier derived from `discount_percent`:

| discount_percent | discount_category |
|-----------------|-------------------|
| = 0             | No Discount       |
| < 10%           | Low Discount      |
| < 25%           | Mid Discount      |
| ≥ 25%           | High Discount     |

Used in `fct_all_ticket_sales` and the `dim_transaction_flags` junk dimension to
segment promotional pricing impact without inflating the fact table's column count.
{% enddocs %}
