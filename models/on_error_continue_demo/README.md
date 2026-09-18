# On-error-continue payment-feed demo

This isolated demo uses five seeded payment events. One amount is malformed and
one is negative, giving you a realistic feed-quality incident to present.

## 1. Load the feed

```bash
dbt seed --select on_error_continue_payment_events
```

## 2. Run the delivery flow

```bash
dbt build --select on_error_continue_payment_events+
```

Safe parsing preserves all events for investigation. The independent
`on_error_continue_payment_review_queue` model reads the seed directly and
materializes the malformed and negative rows. Its structured data test warns
when the queue is non-empty and persists the same rows as
`DBT_TEST__AUDIT.PAYMENT_EVENTS_REQUIRING_REVIEW`. The warning is tagged
`on_error_continue_alert` and owned by `payment_operations_demo`. Because the
queue does not depend on the validator, alert evidence stays current when strict
validation fails.

Expected build result: 26 passed, 1 warned, 0 failed, and 0 skipped.

Expected metrics: 5 total events, 1 malformed amount, 1 negative amount, 1
decline, and a 40% review rate.

## 3. Demonstrate `on_error: continue`

```bash
dbt build --select on_error_continue_payment_validation+ --vars '{"on_error_continue_demo_strict_validation": true}'
```

Expected result:

- `on_error_continue_payment_validation` fails because strict `TO_DECIMAL`
  receives `NOT_A_NUMBER`.
- The command is still non-zero because a model failed.
- `on_error_continue_incident_audit` runs successfully instead of being skipped.
- The audit remains available to explain the incident.

## 4. Demonstrate Jinja exception warning behavior

```bash
dbt build --select on_error_continue_feed_quality --vars '{"on_error_continue_demo_exception_mode": "warn"}'
```

Expected result: dbt logs a custom Jinja warning, then builds and tests the
model. Use the structured data-test warning for automated alert routing.

## 5. Demonstrate Jinja exception error behavior

```bash
dbt build --select on_error_continue_feed_quality --vars '{"on_error_continue_demo_exception_mode": "error"}'
```

Expected result: the macro raises a custom compiler error before Snowflake runs
the model. Attached tests are skipped because the model did not build.

## 6. Monitoring job for Slack

Keep delivery and alerting separate. Configure a dedicated dbt Platform job with:

```bash
dbt test --select tag:on_error_continue_alert --warn-error-options '{"error":["RunResultWarningMessage"]}'
```

The delivery build can complete with a warning. The monitoring job promotes
only the alert test warning to an error, allowing native Slack job-error
notifications without blocking delivery.

In dbt Platform, open **Profile > Notification settings > Slack notifications**,
choose the channel and environment, then enable **Error** for this monitoring
job.

## 7. Email model notifications

The demo models belong to `payment_operations_demo`, owned by
`analyticswithsushil@gmail.com`. Model-owner emails are sent only for jobs in a
deployment environment; interactive Studio commands do not send them. Commit
and push the demo to the deployment branch, create the delivery job, then open
**Profile > Notification settings > Email notifications**. Enable
**Enable group/owner notifications on models** and subscribe to **Warning** for
tests. Leave model **Success** and test **Success** disabled when you only want
actionable alerts. dbt can send the immediate test-warning email followed by a
consolidated end-of-run summary.


## 8. Restore the safe model state

```bash
dbt build --select on_error_continue_payment_events+
```

Both demo variables default to safe behavior. The structured quality test still
warns while the known bad seed rows remain, which is intentional for this demo.
