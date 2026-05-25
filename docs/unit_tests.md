# dbt Unit Tests — Reference Guide

> **Audience:** Analytics engineers working on the `dbt_practice` Theme Park project.  
> **Engine:** dbt-core 1.8+ / dbt-fusion 2.x · Snowflake adapter  
> **Last updated:** 2026-05-06

---

## Table of Contents

1. [What are Unit Tests?](#what-are-unit-tests)
2. [How to Run](#how-to-run)
3. [Test Inventory](#test-inventory)
4. [Tests: demo\_26\_ephemeral\_base](#tests-demo_26_ephemeral_base)
5. [Tests: int\_daily\_revenue](#tests-int_daily_revenue)
6. [Tests: int\_ride\_metrics](#tests-int_ride_metrics)
7. [Tests: int\_customer\_visits](#tests-int_customer_visits)
8. [Tests: stg\_sales\_\_tickets](#tests-stg_sales__tickets)
9. [Tests: stg\_external\_haunted\_\_haunted\_houses](#tests-stg_external_haunted__haunted_houses)
10. [Known Limitations](#known-limitations)

---

## What are Unit Tests?

| Property | Detail |
|---|---|
| **Test SQL logic** | Validate CASE statements, joins, coalesces, calculations |
| **Run before build** | Execute independently — model does not need to be materialized |
| **Pre-defined data** | `given:` provides fixture rows; `expect:` declares exact output |
| **No real data** | Seeds, sources, and warehouse tables are never touched |
| **Dev and CI friendly** | Same command works locally and in any CI pipeline |
| **Defined in yml** | Authored alongside model docs in `schema.yml` files |
| **SQL models only** | Python models are not supported |

Unit tests complement data tests (singular and generic): data tests assert constraints on **real data**; unit tests assert **SQL logic** using synthetic fixtures.

---

## How to Run

```bash
# Run all unit tests
dbt test --select test_type:unit

# Run unit tests for a specific model
dbt test --select test_type:unit demo_26_ephemeral_base
dbt test --select test_type:unit int_daily_revenue
dbt test --select test_type:unit int_ride_metrics
dbt test --select test_type:unit int_customer_visits
dbt test --select test_type:unit stg_sales__tickets
dbt test --select test_type:unit stg_external_haunted__haunted_houses

# Run a single named unit test
dbt test --select "test_spending_tier_boundaries"
dbt test --select "test_is_haunted_filter"
```

> **First-time setup:** The `INTERMEDIATE` schema must exist in Snowflake before  
> running intermediate model unit tests, because those models are ephemeral and  
> never create the schema themselves. Run once per environment:
> ```bash
> dbt run-operation create_schema --args '{"schema_name": "INTERMEDIATE"}'
> ```

---

## Test Inventory

| # | Test Name | Model | File | SQL Logic Tested |
|---|---|---|---|---|
| 1 | `test_spending_tier_boundaries` | `demo_26_ephemeral_base` | `models/macro_demos/schema_demo_26_ephemeral.yml` | CASE thresholds |
| 2 | `test_revenue_category_ilike_mapping` | `demo_26_ephemeral_base` | `models/macro_demos/schema_demo_26_ephemeral.yml` | ILIKE pattern matching |
| 3 | `test_daily_revenue_ticket_only_date` | `int_daily_revenue` | `models/intermediate/schema.yml` | FULL OUTER JOIN left side |
| 4 | `test_daily_revenue_sales_only_date` | `int_daily_revenue` | `models/intermediate/schema.yml` | FULL OUTER JOIN right side |
| 5 | `test_daily_revenue_category_splitting` | `int_daily_revenue` | `models/intermediate/schema.yml` | CASE category bucketing |
| 6 | `test_ride_metrics_no_reviews` | `int_ride_metrics` | `models/intermediate/schema.yml` | Division-by-zero guard |
| 7 | `test_ride_metrics_positive_review_pct` | `int_ride_metrics` | `models/intermediate/schema.yml` | Percentage calculation |
| 8 | `test_ride_metrics_excludes_null_ride_id_feedback` | `int_ride_metrics` | `models/intermediate/schema.yml` | WHERE ride_id IS NOT NULL filter |
| 9 | `test_customer_visit_no_inpark_spend` | `int_customer_visits` | `models/intermediate/schema.yml` | LEFT JOIN + COALESCE |
| 10 | `test_customer_visit_with_spend_and_feedback` | `int_customer_visits` | `models/intermediate/schema.yml` | Multi-join aggregation |
| 11 | `test_is_discounted_flag` | `stg_sales__tickets` | `models/staging/sales/schema.yml` | CASE boolean flag |
| 12 | `test_is_haunted_filter` | `stg_external_haunted__haunted_houses` | `models/staging/external_haunted/schema.yml` | WHERE clause row exclusion |

---

## Tests: demo\_26\_ephemeral\_base

**File:** `models/macro_demos/schema_demo_26_ephemeral.yml`  
**Model SQL:** `models/macro_demos/demo_26_ephemeral_base.sql`  
**Materialization:** ephemeral  

### Test 1 — `test_spending_tier_boundaries`

**Logic under test:**
```sql
CASE
    WHEN total_amount >= 100 THEN 'high'
    WHEN total_amount >= 40  THEN 'mid'
    ELSE                          'low'
END AS spending_tier,

(total_amount >= 100) AS is_high_value
```

**Why it matters:** Boundary values (100, 99.99, 40, 39.99) are the most common source of off-by-one errors in CASE statements.

| Input `total_amount` | Expected `spending_tier` | Expected `is_high_value` |
|---|---|---|
| 150.00 | high | true |
| 100.00 | high (lower boundary) | true |
| 99.99 | mid | false |
| 40.00 | mid (lower boundary) | false |
| 39.99 | low | false |

---

### Test 2 — `test_revenue_category_ilike_mapping`

**Logic under test:**
```sql
CASE
    WHEN category ILIKE '%food%'
      OR category ILIKE '%bev%'   THEN 'Food & Beverage'
    WHEN category ILIKE '%merch%' THEN 'Merchandise'
    WHEN category ILIKE '%ticket%'THEN 'Ticket'
    ELSE                               'Other'
END AS revenue_category
```

**Why it matters:** ILIKE is case-insensitive but partial-match dependent — verifies that mixed-case strings hit the correct bucket and the fallthrough `ELSE` works.

| Input `category` | Expected `revenue_category` |
|---|---|
| `Fast Food` | Food & Beverage |
| `Craft Bev` | Food & Beverage |
| `Gift Merch` | Merchandise |
| `Ticket Upgrade` | Ticket |
| `Parking` | Other |

---

## Tests: int\_daily\_revenue

**File:** `models/intermediate/schema.yml`  
**Model SQL:** `models/intermediate/int_daily_revenue.sql`  
**Materialization:** ephemeral  

**Model overview:** Combines ticket revenue and in-park sales revenue by date using a FULL OUTER JOIN, with all NULL sides coalesced to 0.

```sql
from ticket_revenue t
full outer join sales_revenue s on t.visit_date = s.visit_date
```

---

### Test 3 — `test_daily_revenue_ticket_only_date`

**Logic under test:** FULL OUTER JOIN — left side only (tickets exist, no sales).

**Why it matters:** Confirms that dates with tickets but no in-park sales still appear in the output with `in_park_revenue = 0`, not dropped.

| Column | Expected value |
|---|---|
| `ticket_revenue` | 120.00 (80 + 40) |
| `in_park_revenue` | 0 |
| `food_revenue` | 0 |
| `merch_revenue` | 0 |
| `total_revenue` | 120.00 |
| `unique_visitors` | 2 |
| `tickets_sold` | 2 |

---

### Test 4 — `test_daily_revenue_sales_only_date`

**Logic under test:** FULL OUTER JOIN — right side only (sales exist, no tickets).

**Why it matters:** Confirms that dates with in-park sales but no ticket purchases still appear with `ticket_revenue = 0`, not dropped.

| Column | Expected value |
|---|---|
| `ticket_revenue` | 0 |
| `in_park_revenue` | 25.00 |
| `food_revenue` | 25.00 |
| `total_revenue` | 25.00 |
| `unique_visitors` | 0 |
| `tickets_sold` | 0 |

---

### Test 5 — `test_daily_revenue_category_splitting`

**Logic under test:**
```sql
sum(case when category = 'food'        then total_amount else 0 end) as food_revenue,
sum(case when category = 'merchandise' then total_amount else 0 end) as merch_revenue
```

**Why it matters:** Other categories (e.g. `game`) must contribute to `in_park_revenue` but NOT leak into `food_revenue` or `merch_revenue`.

| Input transactions | `food_revenue` | `merch_revenue` | `in_park_revenue` |
|---|---|---|---|
| food $30 + merch $20 + game $10 | 30.00 | 20.00 | 60.00 |

---

## Tests: int\_ride\_metrics

**File:** `models/intermediate/schema.yml`  
**Model SQL:** `models/intermediate/int_ride_metrics.sql`  
**Materialization:** ephemeral  

**Model overview:** Enriches the ride catalog with aggregated feedback metrics. Rides with no reviews receive `0` via COALESCE. `positive_review_pct` is guarded against division by zero.

```sql
case
    when coalesce(f.total_reviews, 0) > 0
        then round(f.positive_reviews::numeric / f.total_reviews * 100, 2)
    else 0
end as positive_review_pct
```

---

### Test 6 — `test_ride_metrics_no_reviews`

**Logic under test:** LEFT JOIN + COALESCE + division-by-zero guard.

**Why it matters:** A ride with zero feedback rows would cause `NULL / NULL` division without the guard. Confirms the `CASE WHEN total_reviews > 0` returns `0` cleanly.

| Column | Expected value |
|---|---|
| `total_reviews` | 0 |
| `avg_rating` | 0 |
| `positive_reviews` | 0 |
| `negative_reviews` | 0 |
| `positive_review_pct` | 0 |

---

### Test 7 — `test_ride_metrics_positive_review_pct`

**Logic under test:** `ROUND(positive / total * 100, 2)` with conditional SUM by sentiment label.

**Why it matters:** Verifies both the conditional aggregation (counting by sentiment) and the percentage arithmetic, including rounding to 2 decimal places.

| Input | Value |
|---|---|
| positive reviews | 3 |
| negative reviews | 1 |
| total reviews | 4 |
| Expected `positive_review_pct` | **75.00** |

---

### Test 8 — `test_ride_metrics_excludes_null_ride_id_feedback`

**Logic under test:** `WHERE ride_id IS NOT NULL` in the `feedback_agg` CTE.

**Why it matters:** General park comments are logged without a `ride_id`. Without the WHERE clause, those rows would inflate review counts for every ride that gets any feedback. This test proves only feedback explicitly linked to a ride is counted.

| Input feedback row | `ride_id` | Included? |
|---|---|---|
| F1 | 3 | Yes |
| F2 | null | No (filtered out) |
| F3 | null | No (filtered out) |

| Column | Expected value |
|---|---|
| `total_reviews` | 1 (F1 only, not 3) |
| `positive_reviews` | 1 |
| `negative_reviews` | 0 |
| `positive_review_pct` | 100.00 |

---

## Tests: int\_customer\_visits

**File:** `models/intermediate/schema.yml`  
**Model SQL:** `models/intermediate/int_customer_visits.sql`  
**Materialization:** ephemeral  

**Model overview:** Joins ticket purchases with in-park spend and feedback per customer per visit date.

```sql
from tickets t
left join sales    s on t.customer_id = s.customer_id and t.visit_date = s.visit_date
left join feedback f on t.customer_id = f.customer_id and t.visit_date = f.visit_date
```

---

### Test 9 — `test_customer_visit_no_inpark_spend`

**Logic under test:** LEFT JOIN with COALESCE when no sales transaction matches.

**Why it matters:** Confirms `in_park_spend` becomes `0` (not NULL) and `total_visit_spend = ticket_price` alone. Also confirms `avg_rating` is NULL (not 0) when no feedback exists — preserving the distinction between "no feedback" and "zero rating".

| Column | Expected value |
|---|---|
| `in_park_spend` | 0 |
| `total_visit_spend` | 55.00 (ticket only) |
| `avg_rating` | null |

---

### Test 10 — `test_customer_visit_with_spend_and_feedback`

**Logic under test:** Multi-source LEFT JOIN with aggregation — sales sum + feedback avg matched by `customer_id + visit_date`.

**Why it matters:** Verifies that two sales transactions for the same customer+date are summed correctly, and feedback rating is averaged, with both flowing into `total_visit_spend`.

| Input | Value |
|---|---|
| `final_price` (ticket) | 80.00 |
| TX1 `total_amount` | 35.00 |
| TX2 `total_amount` | 25.00 |
| Feedback `rating` | 4 |

| Column | Expected value |
|---|---|
| `in_park_spend` | 60.00 (35 + 25) |
| `total_visit_spend` | 140.00 (80 + 60) |
| `avg_rating` | 4.0 |

---

## Tests: stg\_sales\_\_tickets

**File:** `models/staging/sales/schema.yml`  
**Model SQL:** `models/staging/sales/stg_sales__tickets.sql`  
**Materialization:** view  

---

### Test 11 — `test_is_discounted_flag`

**Logic under test:**
```sql
case
    when discount_amount > 0 then true
    else false
end as is_discounted
```

**Why it matters:** A zero `discount_amount` must produce `false`, not `null`. Tests both cases from the online source — physical source is passed as empty since the CASE logic is the same for both branches of the UNION ALL.

| Input `discount_amount` | Expected `is_discounted` |
|---|---|
| 20.00 | true |
| 0.00 | false |

---

## Tests: stg\_external\_haunted\_\_haunted\_houses

**File:** `models/staging/external_haunted/schema.yml`  
**Model SQL:** `models/staging/external_haunted/stg_external_haunted__haunted_houses.sql`  
**Materialization:** view  

**Model overview:** Reads the shared `raw_rides` table and filters it down to haunted attractions only, then maps `thrill_level` to a numeric `fear_level`.

```sql
with source as (
    select * from {{ source('external_haunted', 'haunted_houses') }}
    where is_haunted = true   -- ← the filter under test
),
renamed as (
    select
        ride_id::int   as haunted_house_id,
        ride_name      as haunted_house_name,
        case thrill_level
            when 'extreme' then 5
            when 'high'    then 4
            when 'medium'  then 3
            when 'low'     then 2
            else 3
        end::int       as fear_level
    from source
)
select * from renamed
```

---

### Test 12 — `test_is_haunted_filter`

**Logic under test:** `WHERE is_haunted = true`

**Why it matters:** `raw_rides` stores both regular rides and haunted houses in the same table. Without the WHERE filter, non-haunted rides (roller coasters, water slides, etc.) would leak into the haunted house dimension and corrupt any downstream analysis that assumes this table is haunted-only.

**Pattern demonstrated:** feeding 2 rows into the fixture and asserting only 1 comes out — the most direct way to verify a WHERE clause.

**Fixture rows:**

| `ride_id` | `ride_name` | `is_haunted` | `thrill_level` | In output? |
|---|---|---|---|---|
| 1 | Dungeon of Doom | **true** | extreme | Yes |
| 2 | Water Splash | **false** | medium | **No — filtered out** |

**Expected output (1 row):**

| `haunted_house_id` | `haunted_house_name` | `fear_level` |
|---|---|---|
| 1 | Dungeon of Doom | 5 |

**YAML definition** (`models/staging/external_haunted/schema.yml`):

```yaml
unit_tests:
  - name: test_is_haunted_filter
    model: stg_external_haunted__haunted_houses
    description: >
      Verifies that WHERE is_haunted = true excludes non-haunted rides.
      Two rows in, one row out — only the haunted ride must appear in output.
      Also confirms thrill_level 'extreme' maps to fear_level 5.
    given:
      - input: source('external_haunted', 'haunted_houses')
        rows:
          - {ride_id: 1, ride_name: 'Dungeon of Doom', thrill_level: 'extreme',
             is_haunted: true,  capacity_per_hour: 200}
          - {ride_id: 2, ride_name: 'Water Splash',    thrill_level: 'medium',
             is_haunted: false, capacity_per_hour: 300}
    expect:
      rows:
        - {haunted_house_id: 1, haunted_house_name: 'Dungeon of Doom', fear_level: 5}
```

> **Key insight:** The `given:` block controls what the source returns during the test — you control the full input set. The WHERE clause is what narrows 2 input rows down to 1 output row. If the filter were removed, both rides would appear and the test would fail with an unexpected second row.

---

## Known Limitations

### dbt-fusion 2.0 preview — ephemeral consumer tests

`demo_26_ephemeral_consumer` consumes the ephemeral model `demo_26_ephemeral_base`. dbt-fusion inlines the ephemeral CTE at compile time but cannot resolve its schema (`__dbt__cte__demo_26_ephemeral_base`) during unit test schema inference. This is a dbt-fusion preview bug — the test has been omitted until the issue is resolved upstream.

**Workaround:** The base model's classification logic (spending tier, revenue category) is fully covered by tests 1 and 2 above. The consumer's `GROUP BY / ROUND / NULLIF` aggregation is low-risk given that coverage.

### INTERMEDIATE schema bootstrap

The `INTERMEDIATE` schema must be created manually the first time unit tests run in a new Snowflake environment, because all intermediate models are ephemeral and never create the schema themselves:

```bash
dbt run-operation create_schema --args '{"schema_name": "INTERMEDIATE"}'
```

Add this step to your CI pipeline before the `dbt test` job.
