# On-Error-Continue and Exception-Handling Demo Guide

## Purpose

This demo shows how a dbt project can keep useful operational work running when
one transformation fails, while still recording data-quality issues and routing
them to email or Slack.

The scenario is a near-real-time payment feed. Five events arrive from a payment
gateway. Most are valid, but one amount is malformed and one is negative. The
demo answers four operational questions:

1. Can safe parsing preserve the feed for investigation?
2. Can an incident-audit model run after strict validation fails?
3. Can dbt warn about bad data without blocking delivery?
4. Can a separate monitoring job convert that warning into an alert?

## Mental model: payment lane and control room

Think of this demo as a payment-processing lane with an independent operations
control room.

```text
Payment events
      |
      v
+----------------------+        strict parsing fails
| Validation lane      | -------------------------------+
| Parse payment amount |                                |
+----------------------+                                |
      |                                                  |
      | valid/safe output                                |
      v                                                  v
Validated payments                            +----------------------+
                                              | Operations control   |
                                              | room / incident audit|
                                              +----------------------+
                                                        |
                                                        v
                                              Counts and bad event IDs
```

The validation lane and control room have different responsibilities:

- **Validation lane:** attempts to produce trusted payment data.
- **Control room:** reports what arrived and what went wrong.
- **`on_error: continue`:** keeps the control-room task eligible to run when the
  validation lane fails.

The control room does not read the failed validator output. It reads the original
feed independently. This is why it can still run. A child that directly queried
the failed relation would remain technically dependent on unavailable output and
could fail too.

### The six building blocks

Use this mapping while presenting the demo:

| Demo component | Mental-model role | Responsibility |
|---|---|---|
| `on_error_continue_payment_events` | Incoming payment feed | Preserves the raw gateway payload, including malformed values |
| `on_error_continue_payment_validation` | Validation lane | Converts raw amounts into trusted numeric values |
| `on_error_continue_incident_audit` | Operations control room | Counts malformed, negative, and declined events independently |
| `on_error_continue_payment_review_queue` | Evidence queue | Materializes the current malformed and negative seed events independently of validation |
| `payment_events_requiring_review` | Alarm sensor | Warns whenever the evidence queue contains one or more rows and persists those rows |
| Monitoring job | Alarm dispatcher | Converts the selected warning into a failed job status for Slack |


### Three separate decisions

The demo separates three decisions that are often mixed together:

1. **Can processing continue?**
   `on_error: continue` answers this for downstream DAG scheduling.
2. **Should the issue be recorded?**
   The warning-level data test records the issue and stores evidence.
3. **Should someone be notified?**
   Email model notifications or the Slack monitoring job route the alert.

Keeping these decisions separate lets the delivery flow remain useful without
hiding quality problems.

### Warning, evidence, and alert

Treat the alerting flow as three layers:

```text
Warning  ->  Evidence  ->  Alert
```

- **Warning:** the test reports that two events violate the payment rule.
- **Evidence:** `PAYMENT_EVENTS_REQUIRING_REVIEW` stores the exact event rows.
- **Alert:** email or Slack tells the owner to investigate those rows.

A warning by itself is only a signal in a dbt run. Persisted rows make it
investigable, and notification routing makes it operational.

### Delivery plane versus monitoring plane

The two-job design creates two operational planes:

```text
Delivery plane                           Monitoring plane
--------------                           ----------------
Build seed and models                    Run alert-tagged tests
Allow warning-level issues               Promote selected warning signal
Publish usable outputs                   Exit non-zero for Slack routing
```

The delivery job answers, “Can we still publish useful data?” The monitoring job
answers, “Does someone need to act?”

### Outcome matrix

| Scenario | Validator | Incident audit | Quality test/model | Command result | Alert behavior |
|---|---|---|---|---|---|
| Safe delivery | Passes with safe parsing | Passes | Test warns and stores two rows | Success with warning | Email warning can fire |
| Strict validation | Fails on `NOT_A_NUMBER` | Still passes | Not the focus of this command | Failure | Parent failure is visible |
| Jinja warning mode | Not selected | Not selected | Model logs warning and passes | Success with warning | Developer-facing log warning |
| Jinja error mode | Not selected | Not selected | Model stops during rendering | Failure | Blocking policy is visible |
| Slack monitor | Already built | Already built | Warning is promoted at command level | Failure by design | Native Slack Error notification fires |

### The sentence to remember

> `on_error: continue` keeps independent work moving; the warning test records
> the problem; the monitoring job turns that problem into an alert.

It is also useful to remember what `on_error: continue` does **not** mean:

- It does not make a failed parent successful.
- It does not guarantee every child can run.
- It does not suppress the error.
- It does not send a notification by itself.

It changes scheduling behavior so independently executable children can continue.

## Key concepts

### `on_error: continue`

The `on_error: continue` model config controls how dbt schedules downstream
nodes after a model fails. It does not convert the failed model into a success.
The command still exits non-zero when the parent fails.

A downstream model can continue only when it is independently executable. In
this demo, the audit model has a DAG dependency on the validator but reads the
seed directly. It therefore does not require the failed validator relation.

### Jinja exceptions

The demo macro uses two dbt exception methods:

- `exceptions.warn()` logs a warning and allows the model to continue.
- `exceptions.raise_compiler_error()` stops the model during Jinja rendering.

Jinja warnings are useful for developer-facing messages. A warning-level data
test is better for automated alerting because it creates a structured test
result in dbt artifacts and can persist the failing rows.

### Structured warning test

The `on_error_continue_payment_review_queue` model selects current malformed and
negative events directly from the seed. The `payment_events_requiring_review`
test uses `warn_if_rows_exist` to warn whenever that queue contains one or more
rows. It is configured with:

- `severity: warn`
- `warn_if: ">0"`
- `store_failures_as: table`
- tag `on_error_continue_alert`

The delivery build therefore succeeds with a warning while the current bad rows
are stored for investigation. Because the queue is independent from strict
validation, the test never needs to inspect a stale validator relation.

## Project structure

```text
seeds/on_error_continue_demo/
├── on_error_continue_payment_events.csv
└── schema.yml

models/on_error_continue_demo/
├── on_error_continue_payment_validation.sql
├── on_error_continue_payment_review_queue.sql
├── on_error_continue_incident_audit.sql
├── on_error_continue_feed_quality.sql
├── groups.yml
├── schema.yml
├── README.md
└── DEMO_GUIDE.md

macros/on_error_continue_demo/
├── apply_on_error_continue_feed_policy.sql
└── test_warn_if_rows_exist.sql
```


## Seed data

The seed contains five payment events:

| Event | Raw amount | Status | Intended behavior |
|---|---:|---|---|
| `EVT-1001` | `49.99` | approved | Valid payment |
| `EVT-1002` | `125.50` | approved | Valid payment |
| `EVT-1003` | `NOT_A_NUMBER` | approved | Malformed amount |
| `EVT-1004` | `-25.00` | refunded | Negative amount requiring review |
| `EVT-1005` | `75.00` | declined | Valid amount with declined status |

The raw amount is loaded as `varchar`. This is intentional: if the seed cast the
column to a numeric type, `NOT_A_NUMBER` would fail during seed loading and the
models would never get a chance to demonstrate safe versus strict parsing.

The seed is created in:

```text
DBT_HLAND.ON_ERROR_CONTINUE_DEMO_SEED.ON_ERROR_CONTINUE_PAYMENT_EVENTS
```

## DAG

```text
on_error_continue_payment_events
              |
              +----------------------+-------------------------+
              |                      |                         |
              v                      v                         v
payment_validation          payment_review_queue       feed_quality
              |                      |
              v                      v
incident_audit              payment_events_requiring_review
                            (warning test + persisted rows)
```

The validation-to-audit edge is declared explicitly with `depends_on`. The audit
reads the seed directly, making it eligible to run after validation fails. The
review queue is a separate seed-derived branch, so its alert evidence is always
based on current feed data rather than the last successful validator table.

## Resource behavior


### Payment validation

`on_error_continue_payment_validation` has two modes.

Safe mode is the default and uses `TRY_TO_DECIMAL`. The malformed amount becomes
`NULL`, and all five events remain available for investigation.

Strict mode is activated with:

```text
on_error_continue_demo_strict_validation: true
```

Strict mode uses `TO_DECIMAL`. Snowflake raises an error for `NOT_A_NUMBER`.
Because the model has `on_error: continue`, dbt still schedules the independent
incident-audit child.

### Payment review queue

`on_error_continue_payment_review_queue` safely parses the raw amount and keeps
only events with a null or negative parsed amount. It is built directly from the
seed and is not downstream of strict validation.

Expected rows:

| Event | Review reason |
|---|---|
| `EVT-1003` | `malformed_amount` |
| `EVT-1004` | `negative_amount` |

The `payment_events_requiring_review` test simply returns every row in this
queue. Non-empty queue means warning; empty queue means pass. This keeps alert
evidence current and prevents tests from querying a stale validator table after
a failed replacement.


### Incident audit

`on_error_continue_incident_audit` reports:

- total events
- malformed amount events
- negative amount events
- declined events
- audit timestamp

Expected values are:

| Metric | Expected value |
|---|---:|
| Total events | 5 |
| Malformed amount events | 1 |
| Negative amount events | 1 |
| Declined events | 1 |

### Feed quality

`on_error_continue_feed_quality` reports:

| Metric | Expected value |
|---|---:|
| Total events | 5 |
| Malformed amount events | 1 |
| Negative amount events | 1 |
| Events requiring review | 2 |
| Review rate | 0.4000 |

It also accepts `on_error_continue_demo_exception_mode` with three values:

- `safe`: build without a Jinja exception
- `warn`: emit a custom warning and continue
- `error`: raise a custom compiler error

## Ownership and notifications

The four models belong to the `payment_operations_demo` group.

```text
Owner: Theme Park Operations
Email: analyticswithsushil@gmail.com
```

The group metadata documents these routes:

- Email: dbt model notifications
- Slack: dedicated monitoring job
- Alert test tag: `on_error_continue_alert`

The group configuration provides ownership metadata in the project. Email and
Slack destinations must also be enabled in dbt Platform notification settings.

## End-to-end presentation

### Step 1: Load the payment feed

```bash
dbt seed --select on_error_continue_payment_events
```

Explain that the raw amount remains a string so malformed gateway payloads can
be retained and inspected.

Expected result: the seed loads five rows successfully. `dbt seed` does not run
seed tests; the descendant tests run in Step 2.

### Step 2: Run the delivery flow

```bash
dbt build --select on_error_continue_payment_events+
```

Explain that safe parsing allows all models to build. The independent review
queue finds the malformed amount and negative refund, and its structured test
warns because the queue is non-empty.

Expected result:

- seed succeeds
- four models succeed
- normal data tests pass
- `payment_events_requiring_review` warns
- no model fails
- no node is skipped
- the overall delivery command succeeds

The validated demo result was:

```text
26 passed
1 warned
0 failed
0 skipped
```


### Step 3: Inspect the quality summary

```sql
SELECT
    total_events,
    malformed_amount_events,
    negative_amount_events,
    events_requiring_review,
    review_rate,
    policy_mode,
    evaluated_at
FROM DBT_HLAND.ON_ERROR_CONTINUE_DEMO.ON_ERROR_CONTINUE_FEED_QUALITY;
```

Expected review rate: `0.4000`, meaning two of five events require review.

### Step 4: Inspect persisted warning rows

```sql
SELECT
    event_id,
    customer_id,
    payment_amount_raw,
    payment_amount,
    currency,
    payment_status,
    event_timestamp,
    review_reason
FROM DBT_HLAND.DBT_TEST__AUDIT.PAYMENT_EVENTS_REQUIRING_REVIEW
ORDER BY event_id;
```

Expected rows:

- `EVT-1003`: raw amount `NOT_A_NUMBER`, parsed amount null, reason `malformed_amount`
- `EVT-1004`: parsed amount `-25.00`, reason `negative_amount`

This persisted table is a copy of the current independent review queue. It is
recreated when the test runs, so it reflects the latest warning records and
does not depend on the strict validator relation.


### Step 5: Demonstrate `on_error: continue`

```bash
dbt build --select on_error_continue_payment_validation+ \
  --vars '{"on_error_continue_demo_strict_validation": true}'
```

Expected result:

- validation fails on `NOT_A_NUMBER`
- the overall command exits non-zero
- the incident audit still runs
- the audit's tests run
- zero nodes are skipped because of the validator failure

Validated result:

```text
8 passed
1 expected failure
0 skipped
```

Presentation message:

> The primary payment transformation failed, but dbt still produced the
> independent incident report. Operations retains visibility into the feed while
> engineering investigates the failed validator.

### Step 6: Demonstrate a Jinja warning

```bash
dbt build --select on_error_continue_feed_quality \
  --vars '{"on_error_continue_demo_exception_mode": "warn"}'
```

Expected warning:

```text
On-error-continue payment feed alert: malformed or negative amounts were
detected; the quality model will continue.
```

The model and its tests continue to run. This demonstrates a developer-facing
warning emitted during Jinja rendering.

### Step 7: Demonstrate a blocking compiler exception

```bash
dbt build --select on_error_continue_feed_quality \
  --vars '{"on_error_continue_demo_exception_mode": "error"}'
```

Expected error:

```text
On-error-continue payment feed rejected: quality policy is set to error.
```

The model stops during rendering. Snowflake does not execute its model SQL, and
attached tests are skipped because there is no newly built model to test.

### Step 8: Run the Slack monitoring command

```bash
dbt test --select tag:on_error_continue_alert \
  --warn-error-options '{"error":["RunResultWarningMessage"]}'
```

The test remains semantically classified as a warning, but dbt exits non-zero
because `RunResultWarningMessage` is promoted to an error at command level. This
is the signal used by native Slack job-error notifications.

This command was validated successfully as an alert simulation: the command
failed as intended and the persisted warning rows remained queryable.

### Step 9: Restore the safe model state

```bash
dbt build --select on_error_continue_payment_events+
```

The models return to their default safe modes. The structured test continues to
warn until the intentionally bad seed rows are removed; that warning is expected
for this demo.

## Recommended deployment jobs

No deployment jobs currently exist for this project. Create two jobs in dbt
Platform.

### Delivery job

Suggested name: `On Error Continue Demo - Delivery`

```bash
dbt build --select on_error_continue_payment_events+
```

Purpose:

- load and transform the feed
- allow warning-level quality issues
- preserve bad rows for investigation
- avoid blocking delivery for this warning threshold

### Monitoring job

Suggested name: `On Error Continue Demo - Alert Monitor`

```bash
dbt test --select tag:on_error_continue_alert \
  --warn-error-options '{"error":["RunResultWarningMessage"]}'
```

Purpose:

- run only alert-tagged tests
- convert their warning result into a non-zero job status
- trigger native Slack job-error notifications
- remain operationally separate from delivery

Schedule the monitoring job after the delivery job or trigger both from the same
external orchestrator in sequence.

## Configure and verify email notifications

Model-owner emails are emitted only by job runs in deployment environments.
Commands run interactively in Studio do not send these emails, even when the
same test returns a warning.

Prerequisites:

- commit and push this demo to the branch used by the deployment environment
- use a deployment environment on a dbt release track
- create or reuse a delivery job such as `alert_test`
- have a dbt administrator enable model notifications for the account

Then configure and verify:

1. Open dbt Platform and select your profile in the lower-left sidebar.
2. Open **Notification settings > Email notifications**.
3. Under **Model notifications**, enable **Enable group/owner notifications on models**.
4. Select **Warning** for tests. Leave model **Success** and test **Success**
   disabled when you only want actionable quality alerts.
5. Confirm the deployed `payment_operations_demo` group owns the review-queue model
   and uses `analyticswithsushil@gmail.com`.
6. Trigger the delivery job in its deployment environment.
7. Wait for the job to finish and check the inbox and spam folder.

The warning test inherits the review-queue model's group. dbt can send an
immediate email for each subscribed status category encountered during the run,
followed by a consolidated end-of-run summary. For this demo, enabling model
Success as well as test Warning produces a model-success email, a test-warning
email, and the summary. Selecting only test Warning removes the model-success
message, though the warning and final summary can both still arrive.


## Configure Slack notifications

1. Create the monitoring job described above.
2. Open **Profile > Notification settings > Slack notifications**.
3. Select the Slack channel.
4. Select the deployment environment.
5. Find `On Error Continue Demo - Alert Monitor`.
6. Enable notifications for **Error**.
7. Save the settings.

The monitoring command exits non-zero when the alert test warns, so the job's
Error notification sends the Slack alert. The separate delivery job can still
complete successfully.

## Why two jobs are recommended

Promoting warnings to errors inside the delivery job would make delivery fail.
Separating delivery and monitoring gives each job one responsibility:

- delivery publishes usable data and records warnings
- monitoring converts selected warnings into alertable job failures

This avoids promoting unrelated dbt warnings, deprecations, or static-analysis
messages into production failures. The monitoring command promotes only
`RunResultWarningMessage` and selects only `on_error_continue_alert` tests.

## Tracking and investigation

Warning history is available through:

- dbt Platform job run history
- `run_results.json`
- the persisted `PAYMENT_EVENTS_REQUIRING_REVIEW` table
- Elementary artifacts collected by the project's run hooks

For an incident, start with the persisted table to identify affected event IDs,
then use the job run to review the warning count and execution context.

## Common questions

### Why does the strict demo command still fail?

`on_error: continue` does not suppress the parent failure. It allows eligible
children to continue. A non-zero command status remains important because it
accurately reports that validation failed.

### Why does the audit not select from the validator?

A child that queries a failed relation is not truly independent. The audit reads
the seed directly so it can run even when strict validation cannot create its
table.

### Why use a data test as well as `exceptions.warn()`?

The Jinja warning is a log message. The data test provides a warning-status node,
a failure count, artifact history, ownership, tags, and persisted offending
rows. Those features make the test suitable for automated alerting.

### Why is the malformed amount stored as text?

Keeping the raw payload as text reflects how ingestion systems commonly land
API events. Parsing belongs in the transformation layer, where safe and strict
policies can be demonstrated explicitly.

### Does a warning-level test make the delivery job fail?

No. With its normal configuration, the delivery command succeeds with a warning.
The dedicated monitoring command intentionally promotes that warning to a
non-zero status for Slack routing.

### What happens when the source data is fixed?

When no rows violate the expression, the test passes. The monitoring job exits
successfully and no Slack error notification is sent.

## Troubleshooting

### Nothing is selected

Confirm the exact selectors:

```bash
dbt ls --select on_error_continue_payment_events+
dbt ls --select tag:on_error_continue_alert
```

### The models cannot find the seed

Reload it:

```bash
dbt seed --select on_error_continue_payment_events --full-refresh
```

### The warning table is missing

Rebuild the review queue with its seed ancestor and attached warning test:

```bash
dbt build --select +on_error_continue_payment_review_queue
```

The command should succeed with one warning and recreate the persisted evidence
table. Then query:

```sql
SELECT *
FROM DBT_HLAND.DBT_TEST__AUDIT.PAYMENT_EVENTS_REQUIRING_REVIEW
ORDER BY event_id;
```


### Slack does not receive an alert

Check that:

- the dedicated monitoring job exists
- its command includes `RunResultWarningMessage`
- the job exits non-zero
- Slack is connected to dbt Platform
- the correct environment and channel are selected
- Error notifications are enabled for the monitoring job

### Email does not arrive

Check that:

- model notifications are enabled for the account
- Warning notifications are enabled for tests
- the deployment environment is selected
- `analyticswithsushil@gmail.com` is an allowed notification recipient
- the model remains assigned to `payment_operations_demo`

## Final validation record

The implementation has been validated on dbt v2 Stable 2.0.5:

- fresh parsing and both documented `dbt ls` selectors succeeded
- normal and full-refresh seed loading each succeeded with five rows
- safe delivery completed with 26 passed, 1 warned, 0 failed, and 0 skipped
- the independent review queue contained `EVT-1003` and `EVT-1004`
- the persisted warning table contained the same two current evidence rows
- strict validation completed with 8 passed, 1 expected failure, and 0 skipped
- the independent incident audit and its tests continued successfully
- Jinja warning mode emitted `dbt1071`; the model and five tests passed
- Jinja error mode stopped rendering; one model failed and five tests skipped
- the normal named warning test succeeded with one warning
- the dedicated monitoring command retained warning test status and exited non-zero

## Checklist

Before presenting:

1. Run the safe delivery command.
2. Confirm the review queue and persisted table contain `EVT-1003` and `EVT-1004`.
3. Confirm the Slack monitoring job uses the exact documented command.
4. Confirm email Warning notifications are enabled.
5. Confirm Slack Error notifications are enabled for the monitoring job.
6. Keep this guide open for the expected outputs and talking points.
