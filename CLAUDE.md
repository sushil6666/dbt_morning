# CLAUDE.md — DBT-SF-code

## Project

Theme Park Analytics — a production-pattern dbt project on Snowflake.
Stack: dbt-snowflake 1.11.3, dbt-fusion 2.0 preview, GitHub Actions CI/CD, Elementary observability.

## Always do

- Use conventional commits: `feat:`, `fix:`, `chore:`, `docs:` with optional scope e.g. `fix(ci):`, `fix(pii):`.
- Exclude Elementary anomaly tests from every `dbt build` command: `--exclude "tag:elementary-tests"`. This is not optional — see `DECISIONS.md`.
- When editing the CI/CD workflow, confirm changes apply to all three jobs (PR slim build, main full build, CD stages) where appropriate.
- PII masking is inverted: `mask_pii` masks everywhere **except** `prod`. New targets are safe by default. Never invert this back to an allowlist.

## Never do

- Change `intermediate` models away from `ephemeral` without an explicit decision — they exist specifically to avoid schema clutter.
- Add `not_null` tests to columns that intentionally aggregate NULL-source data (e.g. `ticket_price` from the feedback source).
- Trigger the CD workflow from a feature branch — all three CD stages always deploy `main`. The workflow enforces this but don't bypass it.
- Enable `dbt_project_evaluator` — it is disabled because its internal models produce trailing-comma SQL that dbt-fusion cannot parse.
- Add `elementary.all_columns_anomalies` tests back to schema files — they were removed because they are doubly broken on dbt-fusion.

## CI behaviour

- **PR builds**: slim CI using `dbt build --select "state:modified+" --defer --state ./production-manifest/`. Falls back to full build if no prior manifest artifact exists.
- **Main push builds**: full `dbt build` — no state comparison.
- **CD pipeline** (`.github/workflows/cd.yml`): manual `workflow_dispatch`, triggered from `main` only. Three independent stages: UAT → Candidate (WAP Write+Audit) → Prod (WAP Publish via `swap_schemas`).
- The `production-manifest` artifact is uploaded after every successful main push and consumed by the next PR slim build. 90-day retention.

## Key file locations

| What | Where |
|---|---|
| CI workflow | `.github/workflows/ci.yml` |
| CD workflow | `.github/workflows/cd.yml` |
| Snowflake profile | `ci/profiles.yml` |
| Project variables | `dbt_project.yml` (vars block) |
| PII macro | `macros/03_pii_masking/mask_pii.sql` |
| WAP macro | `macros/` (`swap_schemas`) |
| Decision log | `DECISIONS.md` |
| Full project reference | `PROJECT_DOCS.md` |

## Decision log

See [DECISIONS.md](DECISIONS.md) for the history of architectural choices and past failures with root causes.
