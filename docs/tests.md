# dbt Tests — Complete Reference

> **Project:** `dbt_practice` Theme Park Analytics  
> **Engine:** dbt-fusion 2.x · Snowflake  
> **Last updated:** 2026-05-06

---

## Table of Contents

1. [Test Types Overview](#test-types-overview)
2. [How to Run](#how-to-run)
3. [Generic Tests](#generic-tests)
   - [Staging Layer](#staging-layer)
   - [Intermediate Layer](#intermediate-layer)
   - [Marts — Core](#marts--core)
   - [Marts — Analytics](#marts--analytics)
4. [Singular Tests](#singular-tests)
5. [Unit Tests](#unit-tests)
6. [Summary](#summary)

---

## Test Types Overview

| Type | Definition location | What it tests | Touches real data? |
|---|---|---|---|
| **Generic** | `schema.yml` columns | Constraints on real warehouse data (PK, FK, allowed values, ranges) | Yes |
| **Singular** | `tests/*.sql` | Custom SQL logic; test fails if any rows are returned | Yes |
| **Unit** | `schema.yml` `unit_tests:` block | SQL transformation logic using pre-defined fixture rows | No |

---

## How to Run

```bash
# All tests (generic + singular + unit)
dbt test

# All tests for a specific model
dbt test --select stg_feedback__visitor_feedback

# Only generic + singular tests (no unit tests)
dbt test --exclude test_type:unit

# Only unit tests
dbt test --select test_type:unit

# One specific unit test by name
dbt test --select "test_is_discounted_flag"

# One specific generic test by type
dbt test --select "test_name:relationships"

# Run as part of a full build
dbt build
```

---

## Generic Tests

Generic tests run against real Snowflake data. They fail if any row violates the constraint.

### Staging Layer

#### `stg_customer_data__customers`
File: `models/staging/customer_data/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `customer_id` | `unique` | — |
| `customer_id` | `not_null` | — |
| `email` | `unique` | — |
| `email` | `not_null` | — |
| `is_vip_member` | `not_null` | — |

---

#### `stg_sales__tickets`
File: `models/staging/sales/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `ticket_id` | `unique` | — |
| `ticket_id` | `not_null` | — |
| `customer_id` | `not_null` | — |
| `ticket_type` | `not_null` | — |
| `ticket_type` | `accepted_values` | `['day_pass', 'weekend_pass', 'annual_pass', 'group_pass']` |
| `final_price` | `not_null` | — |
| `final_price` | `expect_column_values_to_be_between` | `min_value: 0, max_value: 1000` |
| `purchase_channel` | `accepted_values` | `['online', 'in_park', 'kiosk', 'phone', 'referral']` |

---

#### `stg_sales_transactions__sales_transactions`
File: `models/staging/sales/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `transaction_id` | `unique` | — |
| `transaction_id` | `not_null` | — |
| `customer_id` | `not_null` | — |
| `category` | `not_null` | — |
| `category` | `accepted_values` | `['food', 'merchandise', 'game', 'photo']` |
| `total_amount` | `not_null` | — |
| `total_amount` | `expect_column_values_to_be_between` | `min_value: 0, max_value: 5000` |

---

#### `stg_feedback__visitor_feedback`
File: `models/staging/feedback/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `feedback_id` | `unique` | — |
| `feedback_id` | `not_null` | — |
| `customer_id` | `not_null` | — |
| `customer_id` | `relationships` | `to: ref('stg_customer_data__customers'), field: customer_id` |
| `rating` | `not_null` | — |
| `rating` | `accepted_values` | `[1, 2, 3, 4, 5]` |
| `category` | `not_null` | — |
| `category` | `accepted_values` | `['ride', 'food', 'general', 'wait_times', 'staff', 'cleanliness']` |
| `sentiment` | `not_null` | — |
| `sentiment` | `accepted_values` | `['positive', 'neutral', 'negative']` |
| `rating_category` | `not_null` | — |
| `rating_category` | `accepted_values` | `['positive', 'neutral', 'negative']` |

> The `relationships` test on `customer_id` asserts that every feedback record belongs to a known customer — catching orphaned rows if a customer is deleted without cascading the delete to feedback.

---

#### `stg_park_assets__rides`
File: `models/staging/park_assets/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `ride_id` | `unique` | — |
| `ride_id` | `not_null` | — |
| `ride_name` | `not_null` | — |
| `thrill_level` | `not_null` | — |
| `thrill_level` | `accepted_values` | `['low', 'medium', 'high', 'extreme']` |
| `status` | `not_null` | — |
| `status` | `accepted_values` | `['active', 'maintenance', 'closed']` |
| `is_haunted` | `not_null` | — |

---

#### `stg_employees__employees`
File: `models/staging/park_assets/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `employee_id` | `unique` | — |
| `employee_id` | `not_null` | — |
| `full_name` | `not_null` | — |
| `department` | `not_null` | — |
| `department` | `accepted_values` | `['operations', 'food_beverage', 'merchandise', 'security', 'guest_services', 'maintenance']` |
| `is_active` | `not_null` | — |

---

#### `stg_external_haunted__haunted_houses`
File: `models/staging/external_haunted/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `haunted_house_id` | `unique` | — |
| `haunted_house_id` | `not_null` | — |
| `haunted_house_name` | `not_null` | — |
| `fear_level` | `not_null` | — |

---

#### `stg_external_haunted__haunted_house_tickets`
File: `models/staging/external_haunted/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `ticket_id` | `unique` | — |
| `ticket_id` | `not_null` | — |
| `customer_id` | `not_null` | — |
| `haunted_house_id` | `not_null` | — |

---

### Intermediate Layer

Intermediate models are **ephemeral** (no physical DB object). Generic tests here run against the CTE output compiled into each downstream consumer.

#### `int_daily_revenue`
File: `models/intermediate/schema.yml`

| Column | Test |
|---|---|
| `visit_date` | `not_null` |
| `visit_date` | `unique` |

---

#### `int_ride_metrics`
File: `models/intermediate/schema.yml`

| Column | Test |
|---|---|
| `ride_id` | `not_null` |
| `ride_id` | `unique` |

---

### Marts — Core

#### `dim_customers`
File: `models/marts/core/schema.yml`

| Column | Test |
|---|---|
| `customer_id` | `unique` |
| `customer_id` | `not_null` |
| `email` | `unique` |
| `email` | `not_null` |

---

#### `dim_rides`
File: `models/marts/core/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `ride_key` | `unique` | — |
| `ride_key` | `not_null` | — |
| `ride_id` | `unique` | — |
| `ride_id` | `not_null` | — |
| `thrill_level` | `accepted_values` | `['low', 'medium', 'high', 'extreme']` |

---

#### `dim_employees`
File: `models/marts/core/schema.yml`

| Column | Test |
|---|---|
| `employee_key` | `unique` |
| `employee_key` | `not_null` |
| `employee_id` | `unique` |
| `employee_id` | `not_null` |
| `department` | `not_null` |

---

#### `fct_visits`
File: `models/marts/core/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `visit_key` | `unique` | — |
| `visit_key` | `not_null` | — |
| `ticket_id` | `unique` | — |
| `ticket_id` | `not_null` | — |
| `customer_id` | `not_null` | — |
| `customer_id` | `relationships` | `to: ref('dim_customers'), field: customer_id` |
| `visit_date` | `not_null` | — |
| `total_visit_spend` | `not_null` | — |
| `total_visit_spend` | `expect_column_values_to_be_between` | `min_value: 0` (store_failures: true) |

> The `relationships` test on `customer_id` enforces star-schema FK integrity — every visit row must reference a customer that exists in `dim_customers`. Catches tickets that were never matched to a customer record (e.g. from a bad ETL join).

---

#### `fct_sales`
File: `models/marts/core/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `sales_key` | `unique` | — |
| `sales_key` | `not_null` | — |
| `transaction_id` | `unique` | — |
| `transaction_id` | `not_null` | — |
| `customer_id` | `not_null` | — |
| `customer_id` | `relationships` | `to: ref('dim_customers'), field: customer_id` |
| `total_amount` | `not_null` | — |
| `total_amount` | `expect_column_values_to_be_between` | `min_value: 0` |

> The `relationships` test on `customer_id` enforces that every in-park sale is attributable to a known customer in `dim_customers`. Without this, anonymous or mismatched `customer_id` values would silently corrupt customer lifetime value calculations.

---

### Marts — Analytics

#### `agg_daily_revenue`
File: `models/marts/analytics/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `date_day` | `unique` | — |
| `date_day` | `not_null` | — |
| `total_revenue` | `not_null` | — |
| `total_revenue` | `expect_column_values_to_be_between` | `min_value: 0` |
| `unique_visitors` | `not_null` | — |
| `unique_visitors` | `expect_column_values_to_be_between` | `min_value: 0` |

---

#### `agg_customer_lifetime_value`
File: `models/marts/analytics/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `loyalty_tier` | `not_null` | — |
| `loyalty_tier` | `accepted_values` | `['Gold', 'Silver', 'Bronze']` |
| `clv` | `expect_column_values_to_be_between` | `min_value: 0` |

---

#### `agg_ride_popularity`
File: `models/marts/analytics/schema.yml`

| Column | Test | Arguments |
|---|---|---|
| `ride_key` | `unique` | — |
| `ride_key` | `not_null` | — |
| `rating_tier` | `not_null` | — |
| `rating_tier` | `accepted_values` | `['Top Rated', 'Well Rated', 'Average', 'Below Average', 'Not Yet Rated']` |
| `review_volume_rank` | `not_null` | — |
| `rating_rank` | `not_null` | — |

---

## Singular Tests

Singular tests are plain SQL files in `tests/`. The test **passes** when the query returns zero rows and **fails** when any rows are returned.

### `assert_final_price_non_negative`
File: `tests/assert_final_price_non_negative.sql`  
Source: `source('raw', 'raw_tickets')`

**Purpose:** Asserts that no ticket has a negative `final_price`. Even after a discount is applied, the final price must be ≥ 0.

```sql
select ticket_id, base_price, discount_amount, final_price
from {{ source('raw', 'raw_tickets') }}
where final_price < 0
```

**Why it matters:** A bug in discount logic (e.g. discount > base price) could produce negative prices that would silently corrupt revenue calculations downstream.

---

## Unit Tests

Unit tests validate **SQL transformation logic** using pre-defined fixture rows. They do **not** touch the warehouse — no seeds, sources, or real tables are read.

Run all unit tests:
```bash
dbt test --select test_type:unit
```

### `stg_sales__tickets`
File: `models/staging/sales/schema.yml`

| # | Test name | SQL logic tested |
|---|---|---|
| 1 | `test_is_discounted_flag` | `CASE WHEN discount_amount > 0 THEN true ELSE false END` |

**`test_is_discounted_flag`**  
Verifies the boolean flag is `true` for a discounted ticket (`discount_amount = 20.00`) and `false` for a full-price ticket (`discount_amount = 0.00`). Ensures a zero discount produces `false`, not `null`.

---

### `demo_26_ephemeral_base`
File: `models/macro_demos/schema_demo_26_ephemeral.yml`

| # | Test name | SQL logic tested |
|---|---|---|
| 2 | `test_spending_tier_boundaries` | CASE thresholds at 100 and 40 |
| 3 | `test_revenue_category_ilike_mapping` | ILIKE partial-match pattern routing |

**`test_spending_tier_boundaries`**  
Tests all four boundary values of the spending tier CASE expression. Boundary inputs (100.00, 99.99, 40.00, 39.99) are the most common source of off-by-one errors.

| `total_amount` | `spending_tier` | `is_high_value` |
|---|---|---|
| 150.00 | high | true |
| 100.00 | high | true |
| 99.99 | mid | false |
| 40.00 | mid | false |
| 39.99 | low | false |

**`test_revenue_category_ilike_mapping`**  
Verifies that mixed-case strings (`Fast Food`, `Craft Bev`, `Gift Merch`, `Ticket Upgrade`, `Parking`) route to the correct `revenue_category` bucket, and the `ELSE 'Other'` fallthrough works.

---

### `int_daily_revenue`
File: `models/intermediate/schema.yml`

| # | Test name | SQL logic tested |
|---|---|---|
| 4 | `test_daily_revenue_ticket_only_date` | FULL OUTER JOIN left side — no sales on date |
| 5 | `test_daily_revenue_sales_only_date` | FULL OUTER JOIN right side — no tickets on date |
| 6 | `test_daily_revenue_category_splitting` | CASE category buckets (food / merch / other) |

**`test_daily_revenue_ticket_only_date`**  
When a date has tickets but no in-park sales, the FULL OUTER JOIN must still produce a row with `in_park_revenue = 0` (not dropped).

**`test_daily_revenue_sales_only_date`**  
When a date has in-park sales but no ticket purchases, the FULL OUTER JOIN must still produce a row with `ticket_revenue = 0` and `unique_visitors = 0` (not dropped).

**`test_daily_revenue_category_splitting`**  
A `game` transaction contributes to `in_park_revenue` but must not leak into `food_revenue` or `merch_revenue`. Input: food $30 + merch $20 + game $10 → `food_revenue = 30`, `merch_revenue = 20`, `in_park_revenue = 60`.

---

### `int_ride_metrics`
File: `models/intermediate/schema.yml`

| # | Test name | SQL logic tested |
|---|---|---|
| 7 | `test_ride_metrics_no_reviews` | Division-by-zero guard + COALESCE on NULL LEFT JOIN |
| 8 | `test_ride_metrics_positive_review_pct` | `ROUND(positive / total * 100, 2)` |
| 9 | `test_ride_metrics_excludes_null_ride_id_feedback` | `WHERE ride_id IS NOT NULL` filter |

**`test_ride_metrics_no_reviews`**  
A ride with zero feedback rows would cause `NULL / NULL` without the `CASE WHEN total_reviews > 0` guard. Confirms all metrics return `0`, not `NULL` or an error.

**`test_ride_metrics_positive_review_pct`**  
Input: 3 positive + 1 negative = 4 total. Expected `positive_review_pct = 75.00`. Validates both conditional aggregation by sentiment and percentage rounding.

**`test_ride_metrics_excludes_null_ride_id_feedback`**  
The `feedback_agg` CTE filters `WHERE ride_id IS NOT NULL`. General park comments (no ride attached) must not inflate any ride's review counts. Input: 1 review with `ride_id = 3` plus 2 with `ride_id = null`. Expected `total_reviews = 1`, not 3.

---

### `int_customer_visits`
File: `models/intermediate/schema.yml`

| # | Test name | SQL logic tested |
|---|---|---|
| 10 | `test_customer_visit_no_inpark_spend` | LEFT JOIN + COALESCE when no sales match |
| 11 | `test_customer_visit_with_spend_and_feedback` | Multi-join aggregation (sum + avg) |

**`test_customer_visit_no_inpark_spend`**  
When no sales transaction matches the customer+visit_date, `in_park_spend` must coalesce to `0` and `total_visit_spend` must equal `ticket_price` alone. Also confirms `avg_rating` is `null` (not `0`) when no feedback exists — preserving the distinction between "no feedback" and "rated zero".

**`test_customer_visit_with_spend_and_feedback`**  
Two sales transactions for the same customer+date must be summed (`in_park_spend = 60`), and a feedback rating flows into `avg_rating`. Input: ticket $80 + TX1 $35 + TX2 $25 + rating 4 → `total_visit_spend = 140`, `avg_rating = 4.0`.

---

## Summary

| Category | Count |
|---|---|
| Generic — `not_null` | 36 |
| Generic — `unique` | 24 |
| Generic — `accepted_values` | 12 |
| Generic — `relationships` | 3 |
| Generic — `expect_column_values_to_be_between` | 7 |
| **Total generic tests** | **82** |
| Singular tests | 1 |
| Unit tests | 12 |
| **Grand total** | **95** |

### Test commands cheat sheet

```bash
dbt test                                          # all tests
dbt test --select test_type:unit                  # unit tests only
dbt test --exclude test_type:unit                 # generic + singular only
dbt test --select test_name:relationships         # relationship tests only
dbt test --select stg_feedback__visitor_feedback  # all tests for one model
dbt test --select "test_is_discounted_flag"       # one named test
dbt build                                         # build + test in one command
```
