# CD Pipeline Explained

A walkthrough of `.github/workflows/cd.yml` — what each section does and why.

---

## What CD does vs. CI

CI (continuous integration) validates code on every PR and push to `main`. CD (continuous deployment) takes that validated code and promotes it through real Snowflake environments.

```
CI  → runs on every PR / merge     → builds + tests in a throwaway schema
CD  → triggered manually per stage → promotes code through UAT → Candidate → Prod
```

The CD pipeline implements the **Write-Audit-Publish (WAP)** pattern across three stages. Each stage is triggered independently so you can re-run a single stage without repeating the ones before it.

---

## Trigger (`on`)

```yaml
on:
  workflow_dispatch:
    inputs:
      stage:
        description: 'Stage to deploy'
        required: true
        type: choice
        options:
          - uat
          - candidate
          - prod
        default: uat
```

`workflow_dispatch` means the pipeline only runs when you explicitly trigger it from the GitHub Actions UI — never automatically. You pick the stage you want to promote to from a dropdown.

**All three stages always deploy from `main`.** If the workflow is triggered from any other branch, every job's `if:` condition evaluates to false and the run is skipped immediately. This enforces the rule that only code merged into `main` ever reaches UAT, Candidate, or Prod.

```yaml
if: github.ref == 'refs/heads/main' && inputs.stage == 'uat'
```

| Stage | What it means |
|---|---|
| `uat` | Build and test `main` in `DBT_BATCH_UAT` |
| `candidate` | WAP Write + Audit: build and test `main` in `DBT_BATCH_CANDIDATE` |
| `prod` | WAP Publish: swap `DBT_BATCH_CANDIDATE` into `DBT_BATCH_PROD` |

Stages are independent. Selecting `prod` does not re-run `uat` or `candidate` first — it only calls `swap_schemas`. This lets you retry a failed publish without rebuilding.

---

## Concurrency

```yaml
concurrency:
  group: dbt-cd-${{ inputs.stage }}
  cancel-in-progress: false
```

Unlike CI (which cancels stale runs on the same branch), CD never cancels a running deployment. If someone accidentally triggers `prod` twice, the second run queues behind the first rather than killing it mid-swap. A half-completed schema rename would leave prod in an inconsistent state, so `cancel-in-progress: false` is deliberate.

Each stage has its own concurrency group (`dbt-cd-uat`, `dbt-cd-candidate`, `dbt-cd-prod`), so a running UAT deploy doesn't block a prod swap.

---

## Permissions

```yaml
permissions:
  contents: read
  actions:  read
```

Same minimal token as CI. CD doesn't need to write to the repo, open issues, or interact with PRs — it only reads code and runs dbt commands.

---

## Environment variables (`env`)

```yaml
env:
  DBT_PROFILES_DIR:    ${{ github.workspace }}/ci
  SNOWFLAKE_ACCOUNT:   ${{ secrets.SNOWFLAKE_ACCOUNT }}
  SNOWFLAKE_USER:      ${{ secrets.SNOWFLAKE_USER }}
  SNOWFLAKE_PASSWORD:  ${{ secrets.SNOWFLAKE_PASSWORD }}
  SNOWFLAKE_ROLE:      ${{ secrets.SNOWFLAKE_ROLE }}
  SNOWFLAKE_DATABASE:  ${{ secrets.SNOWFLAKE_DATABASE }}
  SNOWFLAKE_WAREHOUSE: ${{ secrets.SNOWFLAKE_WAREHOUSE }}
```

Same pattern as CI. `DBT_PROFILES_DIR` points to `ci/profiles.yml`, which now contains all four targets (`ci`, `uat`, `candidate`, `prod`). Each target uses the same Snowflake credentials but a different hard-coded schema:

| Target | Schema |
|---|---|
| `ci` | `PUBLIC` |
| `uat` | `DBT_BATCH_UAT` |
| `candidate` | `DBT_BATCH_CANDIDATE` |
| `prod` | `DBT_BATCH_PROD` |

The Snowflake credentials in secrets are shared across all environments. In a real multi-account setup you'd use separate secrets per environment, but a single Snowflake account with separate schemas is sufficient for most dbt projects.

---

## GitHub Environments and approval gates

Each job declares a GitHub Environment:

```yaml
environment: uat        # deploy-uat job
environment: candidate  # deploy-candidate job
environment: production # deploy-prod job
```

GitHub Environments are configured in **repo Settings → Environments**. By default they have no protection rules — jobs run immediately. The important one to protect is `production`:

1. Go to **Settings → Environments → production**
2. Enable **Required reviewers** and add your team leads
3. Now the `deploy-prod` job pauses after checkout and waits for a human to click **Approve** before `swap_schemas` runs

This is the approval gate that prevents accidental prod swaps.

---

## Job: `deploy-uat` — Stage 1: dev → UAT

```yaml
deploy-uat:
  if: inputs.stage == 'uat'
  timeout-minutes: 60
  environment: uat
```

**What it does:** Takes the current branch code and runs a full dbt build against `DBT_BATCH_UAT`. This is the first real-data validation after CI's schema-level checks.

### Steps

**dbt seed → UAT**
```yaml
- name: dbt seed → UAT
  run: dbt seed --target uat
```
Loads all seed CSVs into the UAT schema. Seeds must land before models that reference them.

**dbt run → UAT**
```yaml
- name: dbt run → UAT
  run: dbt run --target uat --exclude "tag:elementary-tests"
```
Builds all models into `DBT_BATCH_UAT`. Elementary tests are excluded here for the same reason as CI — `run_query` is incompatible with dbt-fusion at compile time.

**dbt test → UAT**
```yaml
- name: dbt test → UAT
  run: dbt test --target uat --exclude "tag:elementary-tests"
```
Runs every schema, data, and custom test against the UAT data. If any test fails, the job fails and the UAT schema is left in its pre-run state (dbt does not roll back, but the failed run means UAT is not considered validated).

**Parse and display test results**

Reads `target/run_results.json` (written by dbt) and writes a structured table to `$GITHUB_STEP_SUMMARY` — visible on the GitHub Actions run page. Runs with `if: always()` so you see results even when tests fail.

**Deployment summary**

Appends a one-line next-step instruction to the summary:
> ✅ UAT deployment complete. Next step: run this workflow with `stage: candidate`.

---

## Job: `deploy-candidate` — Stage 2: UAT → Candidate (WAP Write + Audit)

```yaml
deploy-candidate:
  if: inputs.stage == 'candidate'
  timeout-minutes: 90
  environment: candidate
```

This is the **WAP Write + Audit** phase. The whole point is that prod is never touched here — `DBT_BATCH_PROD` is completely isolated while the candidate is being built and tested.

### WAP — Write

```yaml
- name: "WAP — Write: dbt seed → candidate"
  run: dbt seed --target candidate

- name: "WAP — Write: dbt run → candidate"
  run: dbt run --target candidate --exclude "tag:elementary-tests"
```

Builds a complete, prod-equivalent dataset in `DBT_BATCH_CANDIDATE`. Every table, view, and seed that would exist in prod is built here first.

### WAP — Audit

```yaml
- name: "WAP — Audit: dbt test → candidate"
  run: dbt test --target candidate --exclude "tag:elementary-tests"
```

Runs all tests against `DBT_BATCH_CANDIDATE`. This is the gate. Two outcomes:

| Outcome | What happens |
|---|---|
| All tests pass | The job succeeds. Candidate is ready to be published. Run `stage: prod` next. |
| Any test fails | The job fails. `DBT_BATCH_PROD` is completely untouched. Fix the issue and re-run `stage: candidate`. |

The `timeout-minutes: 90` is higher than UAT's 60 minutes because the candidate build is the most complete — it mirrors a full prod rebuild.

### Test results summary

The same Python parser from the UAT job runs here, but with WAP-specific messaging. When all tests pass it prints:
> ✅ All N tests passed. Candidate is ready. Run this workflow with `stage: prod` to publish.

When tests fail it prints the failing test names under a header that reads:
> ❌ Failed Tests — Prod will NOT be promoted

---

## Job: `deploy-prod` — Stage 3: Candidate → Prod (WAP Publish)

```yaml
deploy-prod:
  if: inputs.stage == 'prod'
  timeout-minutes: 30
  environment: production
```

This is the **WAP Publish** phase. No dbt models are built here. The only dbt command is `run-operation swap_schemas`, which executes three Snowflake metadata renames.

### WAP — Publish

```yaml
- name: "WAP — Publish: swap_schemas candidate → prod"
  run: |
    dbt run-operation swap_schemas \
      --args '{"candidate_schema": "DBT_BATCH_CANDIDATE", "prod_schema": "DBT_BATCH_PROD"}' \
      --target prod
```

Calls the `swap_schemas` macro (`macros/07_zero_downtime/swap_schemas.sql`). What Snowflake executes:

```sql
-- 1. Clear any leftover backup from a previous swap
DROP SCHEMA IF EXISTS SF_TEST.DBT_BATCH_PROD_BACKUP;

-- 2. Move current prod aside (metadata rename — instant)
ALTER SCHEMA SF_TEST.DBT_BATCH_PROD RENAME TO SF_TEST.DBT_BATCH_PROD_BACKUP;

-- 3. Promote candidate into prod (metadata rename — instant)
ALTER SCHEMA SF_TEST.DBT_BATCH_CANDIDATE RENAME TO SF_TEST.DBT_BATCH_PROD;

-- 4. Drop the backup (cleanup)
DROP SCHEMA IF EXISTS SF_TEST.DBT_BATCH_PROD_BACKUP;
```

All four statements are Snowflake catalog operations — no data is copied or moved. BI tools querying `DBT_BATCH_PROD` see an uninterrupted, consistent schema throughout. The window between steps 2 and 3 (where prod is temporarily renamed to backup) is sub-millisecond.

`timeout-minutes: 30` is much lower than the build jobs because `swap_schemas` completes in seconds. A long timeout here would indicate something is wrong.

### Deployment summary

On success, appends a table to `$GITHUB_STEP_SUMMARY` with the timestamp, actor, branch, and target schema.

### Rollback hint on failure

```yaml
- name: Rollback hint on failure
  if: failure()
```

If the publish step fails (rare, but possible if the candidate schema doesn't exist or a rename permission issue occurs), this step appends the exact rollback command to the summary:

```bash
dbt run-operation swap_schemas \
  --args '{"candidate_schema": "DBT_BATCH_PROD_BACKUP", "prod_schema": "DBT_BATCH_PROD"}' \
  --target prod
```

This swaps the backup back into prod, restoring the last known-good version.

---

## End-to-end flow summary

```
Developer merges PR to main  (CI has already validated the change)
  │
  ▼
Trigger CD: stage = uat
  ├─ dbt seed + run + test --target uat
  └─ ✅ UAT validated
       │
       ▼
Trigger CD: stage = candidate          ← WAP Write + Audit
  ├─ dbt seed + run --target candidate  (Write: build into DBT_BATCH_CANDIDATE)
  ├─ dbt test     --target candidate    (Audit: test everything — prod untouched)
  └─ ✅ Candidate validated
       │
       ▼
Trigger CD: stage = prod               ← WAP Publish
  ├─ [optional] Human approval gate (GitHub Environment: production)
  ├─ dbt run-operation swap_schemas    (Publish: rename CANDIDATE → PROD)
  └─ ✅ Prod updated — BI tools see new data instantly, zero downtime
```

---

## Comparison: CI vs. CD

| | CI (`ci.yml`) | CD (`cd.yml`) |
|---|---|---|
| **Trigger** | Automatic (PR / push to main) | Manual (`workflow_dispatch`) |
| **Purpose** | Validate code is correct | Promote code through environments |
| **Snowflake schema** | `PUBLIC` (throwaway) | `UAT` / `CANDIDATE` / `PROD` |
| **Concurrency** | Cancel old runs (`cancel-in-progress: true`) | Never cancel (`cancel-in-progress: false`) |
| **dbt command** | `dbt build` (run + test together) | `dbt run`, `dbt test`, `dbt run-operation` separately |
| **Approval gate** | None | GitHub Environment on `production` stage |
| **Prod touched?** | Never | Only in `stage: prod`, and only via a schema rename |
