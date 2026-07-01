# Capstone Submission: Ride Popularity and Visitor Satisfaction

## 1. Project Objective
This capstone focused on improving one business domain within the existing dbt project and delivering a new stakeholder-facing analytical model. I selected the **Ride Popularity and Visitor Satisfaction** domain and completed the following work:

- reviewed the existing ride and feedback workflow across staging, intermediate, core, and analytics layers
- identified multiple modeling and usability issues in the current implementation
- improved more than two existing models in the domain
- created one new stakeholder-facing model
- added tests and documentation for all touched models
- validated the work using dbt
- documented the business value of the final output

## 2. Chosen Domain
**Ride Popularity and Visitor Satisfaction**

This domain was selected because the project already had a clear path from ride catalog data and guest feedback into ride-level marts. That made it a strong fit for improving model quality, tightening grain, and delivering a more actionable stakeholder output.

The main lineage reviewed in this domain was:

- `stg_park_assets__rides`
- `stg_feedback__visitor_feedback`
- `int_ride_metrics`
- `dim_rides`
- `agg_ride_popularity`

## 3. Models Reviewed
### Staging models
- `models/staging/park_assets/stg_park_assets__rides.sql`
- `models/staging/feedback/stg_feedback__visitor_feedback.sql`

### Intermediate model
- `models/intermediate/int_ride_metrics.sql`

### Core model
- `models/marts/core/dim_rides.sql`

### Analytics models
- `models/marts/analytics/agg_ride_popularity.sql`
- `models/marts/analytics/ride_satisfaction_opportunities.sql`

## 4. Issues and Opportunities Identified
The following issues and improvement opportunities were identified during review:

1. **The existing ride popularity output was too narrow.**  
   `agg_ride_popularity` ranked rides by review volume and rating, but it did not give business users a clear way to decide what action to take.

2. **Ride feedback aggregation was too loosely defined.**  
   `int_ride_metrics` did not clearly restrict the logic to ride-category feedback, which made the ride satisfaction layer less explicit.

3. **The ride dimension omitted useful operational context.**  
   Important ride attributes such as `status`, `opened_date`, and `min_height_cm` were not being carried into the ride mart layer.

4. **Review coverage was not represented clearly.**  
   A large share of rides had very low or no review volume, but the existing models did not expose a review coverage signal for stakeholders.

5. **Wait time and satisfaction were not brought together into one business-facing output.**  
   The current models could support analysis, but they did not directly highlight rides with high waits and weak guest experience.

6. **There was no stakeholder-facing ride opportunity mart.**  
   The project did not yet include a model that translated ride popularity and satisfaction into recommended operational actions.

## 5. Improvements Made to Existing Models
### 5.1 `int_ride_metrics`
**Grain:** one row per `ride_id`

This intermediate model was improved so it can act as a stronger reusable ride-level input for downstream marts.

Changes made:
- restricted aggregation to ride-category feedback only
- added `min_height_cm`
- added `status`
- added `opened_date`
- added `neutral_reviews`
- added `has_reviews`
- added `review_count_band`
- simplified satisfaction bucketing to derive review sentiment directly from numeric `rating`

Impact:
- made ride satisfaction logic more explicit
- improved reuse of ride-level metrics downstream
- exposed review coverage directly in the intermediate layer

### 5.2 `dim_rides`
**Grain:** one row per `ride_id`

This core dimension was expanded so it carries both ride attributes and ride-level guest experience signals.

Changes made:
- added `min_height_cm`
- added `status`
- added `opened_date`
- added `neutral_reviews`
- added `has_reviews`
- added `review_count_band`
- updated documentation and tests for the expanded ride dimension

Impact:
- made the ride dimension more useful for both operations and analytics
- preserved a clean one-row-per-ride grain
- reduced the need for downstream models to repeatedly derive review coverage logic

### 5.3 `agg_ride_popularity`
**Grain:** one row per `ride_id`

This analytical summary model was redesigned so it is more useful than a simple leaderboard.

Changes made:
- added `status`
- added `has_reviews`
- added `review_count_band`
- added `popularity_segment`
- added `wait_experience_segment`
- updated ranking logic to account for both review volume and rating

Impact:
- made the output more interpretable for business users
- separated rides with strong guest experience from rides that simply have low review volume
- connected popularity and satisfaction with operational context

## 6. New Stakeholder-Facing Model
### `ride_satisfaction_opportunities`
**Path:** `models/marts/analytics/ride_satisfaction_opportunities.sql`  
**Grain:** one row per `ride_id`

This model was created as the final stakeholder-facing output for the capstone.

### Business question answered
**Which rides should the park promote, monitor, or improve based on popularity, guest satisfaction, and wait experience?**

### Key contents of the model
The model combines ride attributes with satisfaction and wait-time context from the ride marts. It includes:

- ride identifiers and descriptive attributes
- review counts
- average satisfaction rating
- positive review percentage
- review volume band
- popularity segment
- wait experience segment
- recommended action
- action priority

### Why this model matters
This model gives operations and guest-experience stakeholders a direct way to:
- identify rides with high waits and weak satisfaction
- distinguish rides that need more awareness from rides that need guest experience fixes
- highlight rides that are strong candidates for promotion
- prioritize follow-up actions instead of reviewing a raw leaderboard

## 7. Tests Added
Tests were added or updated for all touched models.

### `int_ride_metrics`
- `unique` on `ride_id`
- `not_null` on `ride_id`
- `not_null` on `review_count_band`
- `accepted_values` on `review_count_band`
- unit test for a ride with no reviews
- unit test for review aggregation
- unit test confirming null ride feedback is excluded from ride-level metrics

### `dim_rides`
- `accepted_values` on `status`
- `accepted_values` on `review_count_band`
- `not_null` on `total_reviews`
- `not_null` on `neutral_reviews`
- `not_null` on `has_reviews`

### `agg_ride_popularity`
- `accepted_values` on `review_count_band`
- `accepted_values` on `rating_tier`
- `accepted_values` on `popularity_segment`
- `accepted_values` on `wait_experience_segment`
- `not_null` on ranking and segmentation fields

### `ride_satisfaction_opportunities`
- `unique` on `ride_key`
- `unique` on `ride_id`
- `not_null` on `ride_key`
- `not_null` on `ride_id`
- `relationships` to `dim_rides.ride_id`
- `accepted_values` on `review_count_band`
- `accepted_values` on `recommended_action`
- `accepted_values` on `action_priority`
- `not_null` on action and segmentation columns

### Why these tests are appropriate
These tests protect the most important assumptions in the project:
- one row per ride in the ride-level models
- valid ride relationship integrity
- stable ride segmentation outputs
- correct ride-feedback aggregation logic

## 8. Documentation Added
Documentation was added or updated in the following YAML files:

- `models/intermediate/schema.yml`
- `models/marts/core/schema.yml`
- `models/marts/analytics/schema.yml`

The documentation includes:
- model descriptions
- model grain
- column-level business meaning
- explanations of derived segmentation fields
- clear stakeholder meaning for recommended actions

## 9. Validation Evidence
The work was validated with dbt using the following commands:

```bash
dbt parse
```

```bash
dbt build --select int_ride_metrics
```

```bash
dbt build --select +ride_satisfaction_opportunities+
```

### Validation results
- `dbt parse` passed after cleaning up an accidental duplicate YAML model entry during editing.
- `dbt build --select int_ride_metrics` initially failed because the unit tests no longer matched the updated ride-feedback classification logic. The test fixtures and expectations were updated to align with the new implementation.
- `dbt build --select +ride_satisfaction_opportunities+` passed successfully.

### Final validation status
- `dbt parse` passed
- `dbt build --select int_ride_metrics` passed through the final ride-path validation
- `dbt build --select +ride_satisfaction_opportunities+` passed

Final successful build summary:
- **111 success**
- **1 no_op**

## 10. Grain of Key Models
- `int_ride_metrics`: one row per `ride_id`
- `dim_rides`: one row per `ride_id`
- `agg_ride_popularity`: one row per `ride_id`
- `ride_satisfaction_opportunities`: one row per `ride_id`

## 11. Assumptions and Limitations
Two important characteristics of the current seed-backed dataset affect this domain:

1. **Review volume is sparse.**  
   Many rides have one review or no reviews at all, which makes raw popularity rankings noisy.

2. **The current ride mart is based on guest feedback volume, not operational ridership counts.**  
   This means “popularity” in the current project is best interpreted as review-based interest and visibility rather than a direct rider-count metric.

These are important interpretation constraints rather than modeling defects. The ride opportunity mart was designed to handle this by adding review volume bands and explicit action categories.

## 12. Business Summary
The final model, `ride_satisfaction_opportunities`, provides a direct answer to the question:

**Which rides should the business promote, monitor, or improve based on guest feedback and ride experience signals?**

This matters because it allows stakeholders to:
- identify rides with high waits and weak satisfaction for operational follow-up
- identify strong rides with limited review coverage that may need more visibility
- promote rides with strong guest experience and manageable wait times
- prioritize action instead of relying on a simple popularity ranking

The model is especially useful for operations, guest experience, and park leadership because it translates ride-level satisfaction and wait signals into stakeholder-ready recommendations.

## 13. Recommended Next Steps
If this project were extended further, the next steps would be:

1. add actual ride ridership or attendance counts to complement review-based popularity
2. build time-based ride performance views to analyze changes in satisfaction over time
3. add operational ownership fields so action items can be assigned by zone or team
4. extend the stakeholder mart with thresholds that can be tuned by business users

## 14. Deliverables Completed
- updated SQL models
- updated YAML tests and documentation
- one new stakeholder-facing model
- technical summary
- business summary
- validation evidence
- demo script support
