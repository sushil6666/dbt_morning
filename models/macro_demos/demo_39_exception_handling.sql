{{ config(
    materialized='view',
    tags=['macro_demo', 'demo_39', 'exceptions']
) }}

/*
  demo_39_exception_handling
  --------------------------
  PURPOSE:
    Safe reference model for documenting how newer dbt/Fusion runtimes report
    clearer errors.

  WHAT THIS MODEL DOES:
    Returns one row on purpose so the checked-in demo stays buildable and easy
    to select.

  WHERE THE REAL REPROS LIVE:
    See `models/feature_test/` for versioned before/after example files.
    That folder is disabled in `dbt_project.yml`, so the examples stay in git
    without breaking normal parse/build runs.
*/

select
    1 as scenario_id,
    'exception_handling_reference' as scenario_name,
    'safe_demo' as demo_status
