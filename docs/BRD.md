# Business Requirements Document

## Project background and purpose

This project looks most likely to support analytics for a theme park operation with a seasonal haunted attractions program. That is an inference based on model and column names such as `raw_rides`, `raw_tickets`, `raw_sales_transactions`, `raw_feedback`, `raw_haunted_events`, `fct_visits`, `agg_ride_popularity`, `agg_happiest_houses`, and `agg_halloween_spending`.

In a real company, a project like this would exist to give operations, finance, guest services, and marketing a consistent set of models for park visits, ticket revenue, in-park spend, guest satisfaction, ride performance, employee context, and seasonal haunted house analysis. The project also shows how a data team would standardize ticket sales across channels, connect spend to visits, and preserve change history for customers, rides, employees, product pricing, and feedback.

## Business objectives

The final models and exposures in this repo point to a few concrete business objectives.

The first objective is day to day operating visibility. `fct_visits`, `dim_rides`, `agg_ride_popularity`, and the `theme_park_operations_dashboard` and `ride_performance_report` exposures support questions like how many guests visited, which rides are most reviewed, which rides have the best ratings, and where wait times or satisfaction may need attention.

The second objective is revenue monitoring. `fct_all_ticket_sales`, `fct_sales`, `agg_daily_revenue`, and the `daily_revenue_report` exposure support questions like how much revenue came from tickets versus in-park sales, how many tickets were sold, and what revenue per visitor looks like over time.

The third objective is customer analysis. `dim_customers`, `agg_customer_lifetime_value`, and the `customer_insights_report` exposure support questions like which customer segments are most valuable, which customers are VIP members, which lifecycle groups drive more revenue, and where retention or upsell opportunities may exist.

The fourth objective is haunted attractions and seasonal marketing analysis. `fct_haunted_house_tickets`, `agg_happiest_houses`, `agg_fear_vs_ratings`, `agg_ticket_value`, `agg_vip_satisfaction`, `agg_visitor_recommendations`, `agg_house_profitability_by_time`, `agg_halloween_spending`, and the `haunted_house_analytics_dashboard` and `halloween_campaign_analysis` exposures support questions like which haunted houses guests like most, whether fear level affects satisfaction, whether Halloween pricing and discounting change demand, and how visitor recommendation rates behave during the season.

## Scope

### In scope

The scope of this project is defined by the data domains that are actually modeled.

- Customer accounts and membership attributes through `stg_customer_data__customers` and `dim_customers`
- Ticket sales and visit behavior through `stg_sales__tickets`, `stg_sales__ticket_sales_online`, `stg_sales__ticket_sales_physical`, `fct_all_ticket_sales`, and `fct_visits`
- In-park point of sale transactions through `stg_sales_transactions__sales_transactions` and `fct_sales`
- Ride and attraction reference data through `stg_park_assets__rides` and `dim_rides`
- Employee roster and staffing context through `stg_employees__employees` and `dim_employees`
- Ticket product reference data through `stg_park_assets__ticket_types` and `dim_ticket_types`
- Guest feedback and satisfaction through `stg_feedback__visitor_feedback` and the haunted feedback models
- Haunted house analysis through `stg_external_haunted__haunted_houses`, `stg_external_haunted__haunted_house_tickets`, `fct_haunted_house_tickets`, and the haunted aggregate models
- Calendar support through `dim_dates` and `metricflow_time_spine`
- Historical change tracking through snapshots like `snp_customers`, `snp_rides`, `snp_employees`, and `snp_ticket_sales_history`
- Data quality checks through singular tests, generic tests, `dbt_expectations`, and unit tests in selected YAML files

### Out of scope

The following areas appear out of scope because they are not actually modeled here.

- Reservations, hotel stays, parking, mobile app events, or loyalty redemptions
- Detailed workforce scheduling or payroll processing beyond simple employee attributes
- Real payment processor data. `payment_method` is sometimes hardcoded or proxy based in staging
- True haunted house point of sale assignment. `stg_external_haunted__haunted_house_tickets` uses deterministic round robin assignment because the raw ticket source does not contain `haunted_house_id`
- Advanced campaign attribution beyond the seasonal spend and discount patterns in `agg_halloween_spending`
- Real time streaming architecture. The project contains dynamic table and event table demos, but the core business models are batch oriented dbt models

## Stakeholders

Realistic stakeholder roles for a project like this would include:

- Analytics engineering team
- Data analysts
- Finance and revenue operations
- Guest services or customer experience teams
- Park operations teams
- Haunted attractions or seasonal event managers
- Marketing analytics teams
- Business intelligence or reporting consumers

## Success criteria

This project would be considered successful if it gives teams a stable and trusted model layer for the main park analytics questions.

Success would mean ticket revenue, in-park sales, visit counts, customer segmentation, ride performance, and haunted house reporting all come from consistent dbt models instead of duplicated ad hoc SQL. It would also mean the exposed dashboards can be refreshed on a predictable schedule, key data tests pass regularly, and historical changes can be traced through snapshot tables when business attributes change over time.

A practical success signal would be that teams can answer questions like daily revenue, revenue per visitor, ride popularity, CLV by customer segment, and Halloween season spend patterns directly from the marts without building new one off datasets each time.

## Assumptions and constraints

This document assumes the project is intended for Snowflake because `requirements.txt` installs `dbt-snowflake` and several macros and materialization demos are Snowflake specific.

This document also assumes the repo models a theme park with a haunted attractions program because that is the clearest interpretation of names like `raw_rides`, `haunted_house_name`, `fear_level`, `agg_happiest_houses`, and `raw_haunted_events`.

There are a few clear constraints in the code.

Some source fields are missing and are stubbed as NULL or hardcoded values in staging. Examples include `purchase_timestamp`, `visit_hour`, some customer demographic fields, haunted house benefit flags, and some payment method fields.

Several haunted house analyses are based on inferred or compatibility fields rather than direct source capture. The repo itself documents that `stg_external_haunted__haunted_house_tickets` assigns haunted house IDs deterministically and that several haunted feedback columns are always NULL.

The project also contains demo models under `models/macro_demos/`. Those are part of the repo and useful for learning, but they are not the same thing as the primary business marts under `models/marts/core` and `models/marts/analytics`.
