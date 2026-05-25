# CI Pipeline Explained

A walkthrough of `.github/workflows/ci.yml` — what each section does and why.

---

## Trigger (`on`)

```yaml
on:
  pull_request:
    branches: [main]
    types: [opened, synchronize, reopened]
  push:
    branches: [main]
```

The pipeline runs in two scenarios:

| Event | When |
|---|---|
| `pull_request` | A PR is opened, updated (new commit pushed), or reopened against `main` |
| `push` | A commit lands on `main` (i.e., a PR is merged) |

The PR run is for validation (did this change break anything?). The push run is for producing the production manifest artifact that future PRs will compare against.

---

## Concurrency

```yaml
concurrency:
  group: dbt-${{ github.ref }}
  cancel-in-progress: true
```

Only one run per branch at a time. If you push two commits quickly, the first run is cancelled and only the latest runs. This prevents redundant work and race conditions on the same branch.

---

## Permissions

```yaml
permissions:
  contents: read
  actions:  read
```

Minimal GitHub token permissions — read the repo code (`contents`) and read workflow artifacts (`actions`). `actions: read` is needed so the `dawidd6/action-download-artifact` step can look up artifacts from previous runs.

---

## Environment variables (`env`)

```yaml
env:
  DBT_PROFILES_DIR:    ${{ github.workspace }}/ci
  SNOWFLAKE_ACCOUNT:   ${{ secrets.SNOWFLAKE_ACCOUNT }}
  ...
```

`DBT_PROFILES_DIR` tells dbt where to find `profiles.yml`. In this repo, a CI-specific profile lives in the `ci/` folder at the repo root (not the default `~/.dbt/`).

All Snowflake credentials are pulled from GitHub Actions secrets and exposed as environment variables. The `ci/profiles.yml` reads them via `env_var()`.

---

## Job settings

```yaml
runs-on: ubuntu-latest
timeout-minutes: 120
```

The job runs on a fresh Ubuntu runner. `timeout-minutes: 120` kills the job if it exceeds 2 hours — a safety net to prevent a hung dbt run from burning CI minutes indefinitely.

---

## Steps

### 1. Checkout code

```yaml
- name: Checkout code
  uses: actions/checkout@v4
```

Clones the current branch into the runner. Everything else depends on this.

---

### 2. Set up Python

```yaml
- name: Set up Python 3.12
  uses: actions/setup-python@v5
  with:
    python-version: '3.12'
    cache: pip
    cache-dependency-path: requirements.txt
```

Installs Python 3.12 and caches pip packages keyed on `requirements.txt`. If `requirements.txt` hasn't changed since the last run, the pip cache is restored and the next step is near-instant.

---

### 3. Install dbt-snowflake

```yaml
- name: Install dbt-snowflake
  run: pip install -r requirements.txt
```

Installs dbt and the Snowflake adapter (plus any other Python dependencies listed in `requirements.txt`).

---

### 4. dbt deps

```yaml
- name: dbt deps
  run: dbt deps
```

Downloads dbt packages declared in `packages.yml` (e.g., `dbt_utils`, `dbt_expectations`). These are not committed to the repo, so this step is always needed.

---

### 5. Download production manifest

```yaml
- name: Download production manifest
  if: github.event_name == 'pull_request'
  uses: dawidd6/action-download-artifact@v3
  continue-on-error: true
  with:
    name: production-manifest
    workflow: ci.yml
    branch: main
    path: ./production-manifest/
```

Only runs on PRs. Downloads the `manifest.json` that was uploaded after the last successful push to `main`, saving it to `./production-manifest/manifest.json`.

`continue-on-error: true` means a missing artifact (e.g., first-ever run) doesn't fail the job — the next step handles that case with a fallback.

This manifest is the **reference point** for Slim CI: dbt will compare the current branch's compiled graph against it to find what changed.

---

### 6. dbt build — PR (Slim CI)

```yaml
- name: dbt build — changed models + downstream (PR)
  if: github.event_name == 'pull_request'
  run: |
    if [ -f ./production-manifest/manifest.json ]; then
      dbt build \
        --select "state:modified+" \
        --exclude "tag:elementary-tests" \
        --defer \
        --state ./production-manifest/ \
        --threads 4
    else
      dbt build --exclude "tag:elementary-tests"
    fi
```

Only runs on PRs. Two paths:

**Happy path — manifest exists (Slim CI):**

| Flag | What it does |
|---|---|
| `--select "state:modified+"` | Build only nodes that changed vs. the production manifest, plus all their downstream dependents (`+`) |
| `--exclude "tag:elementary-tests"` | Skip Elementary anomaly detection tests — these use `run_query` at compile time which is incompatible with dbt-fusion |
| `--defer` | For unchanged upstream models, resolve refs against the production Snowflake schema instead of rebuilding them in CI |
| `--state ./production-manifest/` | The reference manifest to compare against |
| `--threads 4` | Run up to 4 models in parallel, speeding up the build |

**Fallback — no manifest (full build):**

Runs `dbt build` across the entire project. This only happens the very first time CI runs on a fresh repo before any manifest has been uploaded.

---

### 7. dbt build — main (full build)

```yaml
- name: dbt build — full (main)
  if: github.event_name == 'push'
  run: dbt build --exclude "tag:elementary-tests"
```

Only runs when a PR merges to `main`. Builds every model and test in the project. This is the authoritative production run and produces the `target/manifest.json` that gets uploaded for future PR comparisons.

---

### 8. Parse and display test results

```yaml
- name: Parse and display test results
  if: always()
```

Runs even if earlier steps failed (`if: always()`). Reads `target/run_results.json` (written by dbt after every build) and writes a structured summary to `$GITHUB_STEP_SUMMARY` — the markdown report visible on the GitHub Actions run page.

Outputs:
- Total model and test counts
- Passed tests (capped at 20 shown inline)
- Failed tests (all shown, since these need attention)
- Failed models

---

### 9. Write build summary

```yaml
- name: Write build summary
  if: always()
```

Also runs regardless of outcome. Appends a compact **Status Counts** table to the same `$GITHUB_STEP_SUMMARY` — a quick tally of how many nodes were `pass`, `success`, `warn`, `error`, `fail`, or `skipped`.

Kept as a separate step from "Parse and display test results" so each concern is isolated and one failing doesn't silence the other.

---

### 10. Upload production manifest

```yaml
- name: Upload production manifest
  if: github.event_name == 'push' && success()
  uses: actions/upload-artifact@v4
  with:
    name: production-manifest
    path: target/manifest.json
    retention-days: 90
```

Only runs on a successful push to `main`. Uploads `target/manifest.json` as a GitHub Actions artifact named `production-manifest`, retained for 90 days.

This is what step 5 (Download production manifest) fetches on the next PR. The cycle:

```
PR merged to main
  └─► full build succeeds
        └─► manifest uploaded  ← stored as artifact

Next PR opened
  └─► manifest downloaded
        └─► slim CI compares against it
```

---

## End-to-end flow summary

```
PR opened/updated
  1. Checkout + install
  2. Download manifest from last main build
  3. dbt build --select state:modified+ --defer   (or full build if no manifest)
  4. Write GitHub Step Summary with test/model results

PR merged to main
  1. Checkout + install
  2. dbt build (full)
  3. Write GitHub Step Summary
  4. Upload manifest.json as artifact for next PR
```
