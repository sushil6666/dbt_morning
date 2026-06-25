# Functional Specification

## Functional overview

This project is organized as a standard dbt transformation flow with source-aligned staging models, reusable intermediate models, business-facing marts, snapshots for history, seed data for the raw layer and demos, custom macros, and automated tests.

The most likely business scenario is a theme park and haunted attractions analytics project. That is an inference from the repo structure and model names, not a stated business brief in the codebase.

## Functional breakdown by layer

### Seeds

The base seed files create the raw demo data used by the project.

- `raw_customers.csv` supplies customer account data such as membership type and signup channel
- `raw_rides.csv` supplies ride and attraction reference data
- `raw_tickets.csv` supplies ticket purchase data
- `raw_sales_transactions.csv` supplies in-park point of sale transactions
- `raw_feedback.csv` supplies customer feedback and ratings
- `raw_employees.csv` supplies employee roster data
- `raw_haunted_events.csv` supplies haunted event reference data

The `seeds/macro_demos/` files support the incremental and materialization demos.

### Sources

`models/sources.yml` defines the raw sources and also provides domain aliases such as `customer_data`, `park_assets`, `sales`, `feedback`, `external_haunted`, `employees`, and `sales_transactions`.

Functionally, this gives the project a stable source contract and lets downstream models use business-friendly source groupings instead of hitting raw seeds directly.

### Staging layer

The staging layer standardizes raw data into consistent row grains and naming.

#### Customer staging

- `stg_customer_data__customers` standardizes customer account records and derives business attributes such as `is_vip_member`, `preferred_scare_level`, and `loyalty_points`

#### Sales staging

- `stg_sales__tickets` creates the canonical ticket sales view across all channels
- `stg_sales__ticket_sales_online` isolates online ticket sales and applies online-specific defaults
- `stg_sales__ticket_sales_physical` isolates in-person ticket sales for `in_park`, `kiosk`, and `phone`
- `stg_sales_transactions__sales_transactions` standardizes in-park point of sale transactions

#### Park asset staging

- `stg_park_assets__rides` standardizes ride attributes and operational status
- `stg_employees__employees` standardizes employee roster data
- `stg_park_assets__ticket_types` derives a ticket type dimension from raw ticket transactions

#### Feedback staging

- `stg_feedback__visitor_feedback` standardizes feedback submissions and derives `rating_category`
- `stg_feedback__haunted_visitor_feedback` adapts general feedback into a haunted house analytics shape with `fear_level`, `visitor_type`, and `would_recommend`

#### External haunted staging

- `stg_external_haunted__haunted_houses` derives haunted house dimension rows from haunted rides
- `stg_external_haunted__haunted_house_tickets` creates haunted ticket assignments from ticket sales using deterministic round robin logic

### Intermediate layer

The intermediate models combine staging models into reusable business logic.

- `int_daily_revenue` combines ticket revenue and in-park revenue by `visit_date`
- `int_ride_metrics` joins rides with aggregated visitor feedback metrics
- `int_customer_visits` combines ticket spend, in-park spend, and feedback into one visit-level record per `ticket_id`

### Mart layer

The mart layer is split between core dimensional and fact models and analytics aggregate models.

#### Core marts

- `dim_customers` provides customer segmentation, lifecycle, retention, and upsell attributes
- `dim_rides` provides ride reference data plus lifetime feedback metrics
- `dim_employees` provides employee context including manager and estimated annual salary
- `dim_ticket_types` provides ticket type reference attributes
- `dim_transaction_flags` stores low-cardinality ticket flag combinations for a junk-dimension pattern
- `fct_all_ticket_sales` stores ticket sales from all channels in one fact table with discount and seasonal attributes
- `fct_haunted_house_tickets` stores haunted house ticket facts joined to haunted house attributes
- `fct_sales` stores in-park POS transaction facts
- `fct_visits` stores visit-level facts combining ticket price, in-park spend, and customer rating
- `fct_sales_with_junk_key` stores ticket sales with a reference to `dim_transaction_flags`

#### Analytics marts

- `agg_daily_revenue` provides daily revenue and visitor metrics
- `agg_customer_lifetime_value` provides CLV by loyalty and customer value segment
- `agg_ride_popularity` ranks rides by review volume and rating
- `agg_fear_vs_ratings` compares haunted fear level to satisfaction
- `agg_halloween_spending` groups ticket sales into Halloween proximity buckets
- `agg_happiest_houses` ranks haunted houses by satisfaction and recommendation rate
- `agg_house_profitability_by_time` analyzes haunted house revenue and satisfaction by time slot
- `agg_ticket_value` compares haunted ticket tiers on satisfaction and value
- `agg_vip_satisfaction` compares VIP and non-VIP haunted visitor satisfaction
- `agg_visitor_recommendations` classifies visitor types by recommendation rate and NPS-style segment
- `agg_customer_spending_profile` exists in the repo but the staging documentation says this analysis is currently constrained by missing source fields

### Utility models

- `dim_dates` provides the calendar spine used by reporting models
- `metricflow_time_spine` supports the semantic layer time spine requirement

### Snapshots

The snapshot layer preserves slowly changing history.

- `snp_customers` tracks customer attribute changes using `strategy='check'`
- `snp_employees` tracks employee changes
- `snp_rides` tracks ride changes
- `snp_ticket_sales_history` tracks ticket sale changes such as `ticket_price`, `discount_percent`, and `payment_method`
- `snp_product_pricing_history` tracks ticket product pricing and attribute changes
- `snp_haunted_house_attributes` tracks haunted house attribute changes
- `snp_visitor_feedback_changes` tracks changes to satisfaction and recommendation fields

### Custom macros

The project contains reusable business and platform macros plus Snowflake-specific materialization demos.

Examples of business-facing macros:

- `spending_tier` classifies ticket spend ranges
- `visit_time_of_day` groups visit hours into named time slots
- `incremental_filter` applies environment-aware incremental filtering
- `mask_pii` masks sensitive values outside production
- `cross_db_surrogate_key` generates surrogate keys in an adapter-aware way
- `generate_date_spine` creates date ranges for calendar models
- `apply_cluster_by`, `attach_row_access_policy`, `switch_warehouse`, and `set_session_params` apply Snowflake-specific operational behavior

The `macros/materializations/snowflake/` folder contains custom materializations for `temp_table`, `event_table`, `hybrid_table`, `dynamic_table`, and `iceberg_table`.

### Tests

The repo contains singular tests, YAML data tests, custom generic tests, package-based tests, and unit tests.

- Singular test: `tests/assert_final_price_non_negative.sql`
- Analysis comparison query: `analyses/audit_stg_tickets.sql`
- Custom generic tests live under `macros/11_generic_tests/`
- Unit tests are defined in YAML for intermediate and selected staging/demo models

## Data flow narrative

Raw seeded data is declared in `models/sources.yml`. Customer data flows from `raw_customers` to `stg_customer_data__customers`, then into `dim_customers`, and finally into downstream models like `agg_customer_lifetime_value` and `fct_visits`.

Ticket data flows from `raw_tickets` into `stg_sales__tickets`, `stg_sales__ticket_sales_online`, and `stg_sales__ticket_sales_physical`. Those channel-specific models union into `fct_all_ticket_sales`. Ticket data also contributes to `int_customer_visits`, which feeds `fct_visits`, and to `int_daily_revenue`, which feeds `agg_daily_revenue`.

In-park sales flow from `raw_sales_transactions` to `stg_sales_transactions__sales_transactions`, then into `fct_sales` and also into `int_customer_visits` and `int_daily_revenue`.

Ride data flows from `raw_rides` to `stg_park_assets__rides`, then into `int_ride_metrics`, then into `dim_rides`, and then into `agg_ride_popularity` and ride-related dashboard exposures.

Feedback flows from `raw_feedback` to `stg_feedback__visitor_feedback`. That data contributes to `int_ride_metrics` for ride quality metrics and to `int_customer_visits` for visit-level satisfaction. It also flows into `stg_feedback__haunted_visitor_feedback`, which powers haunted aggregates like `agg_happiest_houses`, `agg_fear_vs_ratings`, and `agg_visitor_recommendations`.

Haunted house reference data flows from `raw_rides` through `stg_external_haunted__haunted_houses`. Haunted ticket analysis flows from `raw_tickets` through `stg_external_haunted__haunted_house_tickets` into `fct_haunted_house_tickets`, which supports haunted dashboard exposures.

Date enrichment flows through `dim_dates`, which is joined into `fct_sales`, `fct_visits`, and `agg_daily_revenue`. Seasonal analysis also uses `dim_dates.days_to_halloween` in `agg_halloween_spending`.

## Business logic rules in plain English

The repo encodes a number of specific business rules.

Ticket purchases are split into online and physical channels. `stg_sales__ticket_sales_online` keeps only `purchase_channel = 'online'`. `stg_sales__ticket_sales_physical` covers non-online purchases and the test logic now expects `in_park`, `kiosk`, and `phone` source values.

`stg_sales__tickets` treats `ticket_id` as the canonical ticket grain across all channels. It derives `is_discounted` from `discount_amount > 0` and converts empty `promo_code` values to NULL.

`int_daily_revenue` uses a full outer join between ticket revenue and in-park sales so dates with activity in only one source still appear.

`fct_all_ticket_sales` derives `discount_category` with the following bands: `No Discount`, `Low Discount`, `Mid Discount`, and `High Discount`. It also derives `same_day_visit`, `advance_purchase`, `visit_time_category`, and `business_season`.

`agg_halloween_spending` groups visits relative to Halloween into named buckets such as `Halloween Day`, `Week of Halloween`, `October Pre-Halloween`, `2 Months Before`, and `Post Halloween (2 wks)`.

`stg_customer_data__customers` derives `is_vip_member` and `preferred_scare_level` from `membership_type`. It also calculates age from `date_of_birth` at refresh time, which means age is current-state, not historical.

`stg_feedback__visitor_feedback` derives `rating_category` from numeric ratings. Ratings 4 and 5 are `positive`, 3 is `neutral`, and 1 and 2 are `negative`.

`stg_feedback__haunted_visitor_feedback` sets `would_recommend` to TRUE when `satisfaction_rating >= 4`.

`agg_happiest_houses` filters haunted feedback using `var('min_satisfaction_rating')`, which defaults to 3. That means the model intentionally excludes lower-rated feedback from the ranking.

`stg_external_haunted__haunted_house_tickets` assigns `haunted_house_id` by deterministic round robin because the raw ticket source does not actually contain a haunted house identifier. This is an analytical approximation, not a recorded transactional field.

The snapshot models use `strategy='check'` and compare selected business fields to detect changes over time. `snp_customers` also uses `invalidate_hard_deletes = true`.

## Test coverage and why it matters

The project tests key business assumptions at multiple levels.

`stg_sales__tickets` checks uniqueness, not nulls, accepted values, duplicate keys, and purchase versus visit date ordering. This protects the integrity of ticket reporting and visit analysis.

Customer, ride, employee, feedback, and haunted staging models use not null, uniqueness, accepted values, and relationship tests. These protect trusted joins and prevent bad category drift.

The singular test `assert_final_price_non_negative.sql` makes sure raw tickets do not produce negative paid amounts. From a business perspective, this protects revenue reporting from obviously invalid values.

The unit tests in `models/intermediate/schema.yml` verify key transformation logic such as how revenue is coalesced across dates, how ride review percentages are calculated, and how visit-level spend behaves when matching sales or feedback data is absent. These tests matter because they validate the business meaning of the transformation logic, not just the schema shape.

The repo also uses package-based tests from `dbt_expectations` and custom generic tests from `macros/11_generic_tests/`, which extends trust checks beyond the built-in dbt test set.
