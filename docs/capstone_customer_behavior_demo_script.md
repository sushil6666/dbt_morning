# Demo Script: Ride Popularity and Visitor Satisfaction Capstone

## 1. Opening
For this capstone, I worked in the **Ride Popularity and Visitor Satisfaction** domain. My goal was to improve the existing ride satisfaction pipeline and deliver a stakeholder-ready model that helps the business decide which rides to promote, monitor, or improve.

The final output is a new model called `ride_satisfaction_opportunities`, built at **one row per ride**.

## 2. Scope of the DAG
The part of the DAG I worked on starts in the ride catalog and feedback staging models, then flows through the ride metrics layer and into the stakeholder-facing mart.

The main path is:
- `stg_park_assets__rides`
- `stg_feedback__visitor_feedback`
- `int_ride_metrics`
- `dim_rides`
- `agg_ride_popularity`
- `ride_satisfaction_opportunities`

## 3. Problems I identified
There were a few issues in the existing project that made this domain a strong candidate for improvement:

1. Ride popularity output was too narrow and leaderboard-focused.
2. Ride feedback aggregation was not explicit enough about using ride-category feedback.
3. The ride dimension was missing useful operational context.
4. Review coverage was not surfaced clearly.
5. There was no stakeholder-facing ride opportunity mart.

## 4. Existing models improved
### `int_ride_metrics`
I improved the intermediate ride model so it now captures a clearer and more useful set of ride-level metrics, including:
- review coverage
- review volume banding
- neutral review counts
- operational context such as ride status and opened date

This made the intermediate ride layer more reusable and more explicit about how ride satisfaction is calculated.

### `dim_rides`
I expanded the ride dimension so it now carries a fuller set of ride attributes and review coverage signals, making it a better source for downstream analytics.

### `agg_ride_popularity`
I redesigned this model so it is not just a rank-ordered list. It now includes:
- popularity segments
- wait experience segments
- better interpretation of review coverage

## 5. New model created
### `ride_satisfaction_opportunities`
This is the new stakeholder-facing mart.

**Grain:** one row per `ride_id`

It includes:
- ride details
- review counts
- average rating
- positive review percentage
- popularity segment
- wait experience segment
- recommended action
- action priority

## 6. Business question answered
This model answers:

**Which rides should the park promote, monitor, or improve based on popularity, guest satisfaction, and wait experience?**

A stakeholder could use it to:
- identify rides with high waits and weak satisfaction
- identify rides that perform well and should be promoted
- distinguish rides that need more awareness from rides that need operational fixes
- focus review conversations on recommended actions instead of raw rankings

## 7. Tests and documentation
I added tests and documentation across the touched models.

Examples include:
- unit tests for `int_ride_metrics`
- ride-grain uniqueness and not-null tests
- relationship tests back to `dim_rides`
- accepted values tests on segmentation and action fields
- updated model and column documentation in YAML

## 8. Validation
I validated the work with dbt.

Commands used:
```bash
dbt parse
```

```bash
dbt build --select int_ride_metrics
```

```bash
dbt build --select +ride_satisfaction_opportunities+
```

The final parse and ride-path build both passed successfully.

## 9. Important limitation to mention in the demo
There are two current data limitations in the seed-backed project state:

1. Review volume is sparse, so many rides have one or no reviews.
2. Popularity in the current project is review-based, not direct ridership-based.

That means the stakeholder mart is best used as a ride feedback and ride experience prioritization tool, not as a direct substitute for actual ridership reporting.

## 10. Closing
The main value of this capstone is that it turns the ride domain into something much more actionable.

Instead of only having a ride ranking output, the project now has a stakeholder-facing ride opportunity mart that can support operations, guest experience review, and ride promotion decisions at the correct grain.
