# DECISIONS.md — Architecture Decisions & Failure Log

## How to read this file

Each entry has:
- **Decision / Failure** — what was chosen or what broke
- **Why** — the reason, constraint, or root cause
- **Outcome / Rule** — what to do going forward

---

## Architecture Decisions

### D-01 — Intermediate models are ephemeral

**Decision:** All models under `models/intermediate/` are materialized as `ephemeral`.

**Why:** Intermediate models contain pure business logic CTEs that have no direct BI consumer. Ephemeral avoids creating physical objects in the `INTERMEDIATE` schema while still letting downstream marts reference them. Schema is created via `on-run-start` hook as a no-op safety measure only.

**Rule:** Do not change intermediate models to `table` or `view` without a deliberate decision. The only reason to do so would be if a model needs to be queried independently (e.g. debugging, direct BI access) — in which case it should be promoted to a mart.

---

### D-02 — Staging as views, marts/utilities as tables

**Decision:** `staging` → views; `marts`, `utilities` → tables; `macro_demos` → views.

**Why:** Staging views are thin cleaning layers with no aggregation — materializing them as tables wastes warehouse credits and storage. Marts need table performance for BI tools. Macro demos are educational and rarely queried.

**Rule:** Do not change staging to tables. See F-02 for the failed experiment.

---

### D-03 — PII masking uses inverted (denylist) logic

**Decision:** `mask_pii` masks customer email in all targets **except** `prod`.

**Why:** The original implementation used an allowlist (`['dev', 'staging', 'ci']`). When the `uat` target was added, it was missed and exposed raw customer data in UAT. Inverted to a denylist so new targets are safe by default and `prod` must be explicitly opted out.

**Commit:** `fabf422` (`fix(pii): mask in all non-prod targets`)

**Rule:** Never revert to allowlist logic. The only safe default is: mask everywhere, exclude prod explicitly.

---

### D-04 — Slim CI uses `state:modified+` with deferred state

**Decision:** PR builds run `dbt build --select "state:modified+" --defer --state ./production-manifest/`.

**Why:** Full builds on every PR are slow and expensive. Slim CI only builds models changed in the PR plus their downstream dependents, and defers unmodified upstream models to the production manifest. The production manifest artifact is uploaded on every successful main push (90-day retention).

**Rule:** Always pass `--exclude "tag:elementary-tests"` alongside slim CI commands. If no manifest artifact exists (first PR on a fresh repo), CI falls back to a full build.

---

### D-05 — WAP (Write-Audit-Publish) pattern for zero-downtime deployments

**Decision:** Production deployments use a schema-level Write-Audit-Publish pattern via the `swap_schemas` macro. Candidate stage builds into `DBT_BATCH_CANDIDATE`, audits there, then `swap_schemas` atomically renames candidate → prod and prod → old.

**Why:** Table-level `swap_table` is fragile when mart schemas have many tables and cross-table references. Schema-level swap is atomic and leaves a full rollback schema (`_old`) immediately available.

**CD stages:**
1. UAT — full build + test in `DBT_BATCH_UAT`
2. Candidate — WAP Write + Audit in `DBT_BATCH_CANDIDATE`
3. Prod — WAP Publish via `swap_schemas`

**Commit:** `1419ee0`

---

### D-06 — CD must be triggered from `main` only

**Decision:** All three CD stages (`deploy-uat`, `deploy-candidate`, `deploy-prod`) have an explicit `github.ref == 'refs/heads/main'` guard. Triggering from any other branch skips all jobs.

**Why:** The original CD workflow had no branch guard. A manual trigger from a feature branch would deploy unmerged, untested code to UAT or prod. Added hard guard after identifying the gap.

**Commit:** `638276b`

**Rule:** Never remove the ref guard from CD jobs.

---

### D-07 — `generate_schema_name` routes WAP targets to a single flat schema

**Decision:** When `target.name` is `uat`, `candidate`, or `prod`, `generate_schema_name` ignores any `+schema` custom suffix and returns `target.schema` as-is. For `dev` and `ci` targets, the custom schema name is used verbatim (e.g. `staging`, `marts`, `raw`).

**Why:** The WAP `swap_schemas` macro performs a single `ALTER SCHEMA ... RENAME TO` operation. That requires all models to land in one schema (`DBT_BATCH_CANDIDATE`) so the rename is atomic. With the original macro, every model used its custom schema name unconditionally — staging went to `STAGING`, marts to `MARTS`, etc. — regardless of target. WAP schemas (`DBT_BATCH_UAT`, `DBT_BATCH_CANDIDATE`) were always empty, and `swap_schemas` had nothing to rename.

**Commit:** `e0449c1`

**Rule:** WAP targets must never re-introduce custom schema suffixes. If per-environment schema separation is ever needed inside WAP, the `swap_schemas` macro must be extended to rename multiple schemas, and this decision revisited.

---

### D-08 — `swap_schemas` called with `keep_backup: true` in CD

**Decision:** The prod stage passes `keep_backup: true` to `swap_schemas`, retaining `DBT_BATCH_PROD_BACKUP` after a successful publish.

**Why:** The original call used the default `keep_backup: false`, which dropped the backup immediately after the swap. The rollback hint in the workflow's failure block referenced `DBT_BATCH_PROD_BACKUP` — a schema that no longer existed after a clean run. Any operator following the hint would find nothing to restore from. With `keep_backup: true`, the previous prod schema survives until the next publish cycle overwrites it.

**Rollback procedure (after a successful publish):**
```bash
dbt run-operation swap_schemas \
  --args '{"candidate_schema": "DBT_BATCH_PROD_BACKUP", "prod_schema": "DBT_BATCH_PROD", "keep_backup": false}' \
  --target prod
```

**Commit:** `04a1543`

**Rule:** Always pass `keep_backup: true` in the CD prod publish step. Never drop the backup manually until the next successful publish has confirmed the new prod is healthy.

---

## Failure Patterns

### F-01 — Elementary anomaly tests break CI on dbt-fusion

**What broke:** `volume_anomalies` and `all_columns_anomalies` tests fail during compilation on dbt-fusion 2.0 preview.

**Root cause:** Elementary anomaly tests use `run_query` inside Jinja during compilation to create intermediate metric temp tables (e.g. `METRICS__TMP_...`). dbt-fusion does not execute `run_query` during compilation — the tables are never created — so the compiled test SQL references non-existent objects and fails with `Object '...' does not exist or not authorized`.

**Fix applied:**
- All `dbt build` commands pass `--exclude "tag:elementary-tests"` (CI and CD).
- All `all_columns_anomalies` entries removed from schema files (12 occurrences across 6 models) — commit `3609f9a`.
- All `volume_anomalies` entries removed from schema files (25 occurrences across 8 files: `sources.yml`, all staging subdirs, `marts/analytics`, `marts/core`) — same root cause.
- Elementary package kept in `packages.yml` for metadata tables and lineage, just not anomaly tests.

**Commits:** `3609f9a`, `8b2520f`

**Rule:** Do not re-add any Elementary anomaly tests (`volume_anomalies`, `all_columns_anomalies`, or any `elementary.*` test that uses `run_query` during compilation) until dbt-fusion reaches GA and confirms `run_query` executes during compilation. Tests run fine locally against dbt-core. Note: `--exclude "tag:elementary-tests"` alone is insufficient — dbt-fusion compiles all test SQL before applying the tag filter, so the compilation error fires regardless. The tests must be removed from schema files entirely.

---

### F-02 — Staging materialized as tables caused Elementary version conflict

**What broke:** Changing staging and macro_demos to `table` materialization was reverted in the same PR cycle.

**Root cause:** The change was bundled with pinning Elementary to `0.23.1`. The combination broke CI (Elementary 0.23.1 has API incompatibilities with the dbt-snowflake version in use). The materialization change itself was valid but could not be isolated from the Elementary pin failure.

**Fix applied:** Full revert (`173a6a2`). Staging remains views, Elementary version constraint left as `>=0.16.0, <1.0.0`.

**Rule:** Do not pin Elementary to a specific patch version without first verifying compatibility with the current dbt-snowflake version in `requirements.txt`.

---

### F-03 — Elementary schema must be initialized before `dbt build`

**What broke:** CI failed with a SQL compilation error on Elementary metrics temp tables even before the dbt-fusion `run_query` issue was understood.

**Root cause:** Elementary requires its internal schema and tables to exist before `dbt build` runs. On a fresh CI runner with no prior state, the schema did not exist. `elementary.on_run_start()` assumes the schema exists; it does not create it.

**Fix applied:** Added an explicit `dbt run-operation elementary.edr_log_unstructured` (or equivalent schema init step) in CI before the build step. Subsequently superseded by the broader decision to exclude Elementary anomaly tests entirely (F-01).

**Commit:** `3db28cc`

---

### F-04 — `not_null` tests on knowingly-null aggregation columns

**What broke:** `not_null` tests on `total_revenue`, `avg_ticket_price`, and `avg_price` in `marts/analytics` failed in CI.

**Root cause:** These columns aggregate `ticket_price` from `stg_feedback__haunted_visitor_feedback`, which does not carry price data — `ticket_price` is NULL by design in the feedback source. Schema descriptions documented this correctly; the tests contradicted the documentation.

**Fix applied:** Removed the `not_null` tests from those three columns.

**Commit:** `9bc98d0`

**Rule:** Before adding `not_null` tests to aggregated numeric columns, trace the source column back to its seed/source and verify it is actually non-null at the source.

---

### F-05 — `dbt_project_evaluator` disabled due to dbt-fusion SQL incompatibility

**What broke:** `dbt_project_evaluator` internal models fail to compile on dbt-fusion 2.0 preview. Additionally, the package's `dbt_project_evaluator_exceptions` seed was being created in `DBT_BATCH_UAT` (the only object in that schema) because it carries no custom `+schema` override.

**Root cause (models):** The package generates SQL with trailing commas that dbt-fusion's parser rejects.

**Root cause (seeds):** `+enabled: false` in the `models:` block only disables models. Seeds are a separate node type and require their own `+enabled: false` under the `seeds:` block.

**Fix applied:**
```yaml
models:
  dbt_project_evaluator:
    +enabled: false

seeds:
  dbt_project_evaluator:
    +enabled: false
```

**Commit:** `e0449c1`

**Rule:** When disabling a package, always add `+enabled: false` under both `models:` and `seeds:` (and `snapshots:` if the package uses them). Do not re-enable until the package publishes a dbt-fusion-compatible release.

---

### F-06 — `{{ macro() }}` in SQL comments, YAML descriptions, and YAML `#` comments is evaluated by dbt

**What broke:** CI failed with `'set_session_params' is undefined` even though the macro existed in the macros folder. The macro was referenced only as a documentation example, not as a real hook.

**Root cause:** dbt (and dbt-fusion) runs the Jinja templating engine over entire files before any SQL or YAML parsing. This means:
- `{{ macro() }}` inside `/* */` SQL block comments — **evaluated**
- `{{ macro() }}` inside YAML `description:` fields — **evaluated**
- `{{ macro() }}` on YAML `#` comment lines — **evaluated** (Jinja runs before YAML strips `#` lines)

The only safe way to prevent evaluation is `{# #}` Jinja comments, or writing examples as plain text without `{{ }}` delimiters.

**Fix applied:** Removed `{{ }}` delimiters from all documentation examples in SQL comments and YAML descriptions. Examples now read as plain text:
```
pre_hook="set_session_params(timezone='UTC', week_start=1, use_cached_result=false)"
```

**Commits:** `78280db`, `a45b745`

**Rule:** Never write `{{ macro_call() }}` inside SQL block comments, YAML description fields, or YAML `#` comment lines. Use plain text for examples (drop the `{{ }}`), or wrap in a `{# #}` Jinja comment if the surrounding context is a `.sql` file. This applies to all files dbt processes: `.sql` model files, `.yml` schema files, and `docs/*.md` files that contain `{%` Jinja tags.

---

## Package Compatibility Notes

| Package | Version constraint | Notes |
|---|---|---|
| `elementary-data/elementary` | `>=0.16.0, <1.0.0` | Anomaly tests excluded from CI (F-01). Do not pin to a patch version (F-02). |
| `dbt-labs/dbt_project_evaluator` | `>=1.0.0, <2.0.0` | Disabled — dbt-fusion trailing-comma incompatibility (F-05). |
| `flexanalytics/dbt_observability` | `3.3.1` (git) | Pinned by revision; tracks observability across dev/uat/prod environments. |
| `dbt-labs/dbt-audit-helper` | `0.12.0` (git) | Used in `analyses/` for migration comparison queries. |
