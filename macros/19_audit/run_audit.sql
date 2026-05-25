{#
  log_model_start()  /  log_model_end()
  -----------------------------------------------------------------------
  Pre/post-hook pair that writes a structured audit record to
  SF_TEST.AUDIT.DBT_RUN_LOG for every model that uses them.

  log_model_start()  — pre-hook
    1. Creates the AUDIT schema if it does not exist.
    2. Creates DBT_RUN_LOG if it does not exist.
    3. Inserts a row with status = 'running' and started_at = now.

  log_model_end()  — post-hook
    Updates that row with:
      status          = 'success'
      completed_at    = CURRENT_TIMESTAMP()
      rows_loaded     = COUNT(*) from the just-built table
      elapsed_seconds = DATEDIFF('second', started_at, completed_at)

  WHY THIS MATTERS IN PRODUCTION:
    - Compliance: regulators ask "when was this dataset last refreshed?"
    - SLA monitoring: detect models drifting over their time budget
    - Debugging: know exactly which dbt run produced the data a BI tool
      is showing — cross-reference with SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY

  AUDIT LOG TABLE SCHEMA (SF_TEST.AUDIT.DBT_RUN_LOG):
    run_id          — dbt invocation_id (same for all models in one `dbt run`)
    model_name      — this.name
    target_schema   — fully qualified schema (database.schema)
    target_env      — dev / uat / prod
    started_at      — pre-hook timestamp (TIMESTAMP_NTZ, UTC)
    completed_at    — post-hook timestamp (TIMESTAMP_NTZ, UTC)
    status          — 'running' → 'success'
    rows_loaded     — row count of the built table
    elapsed_seconds — wall-clock seconds for the model build

  MULTI-STATEMENT NOTE:
    Snowflake rejects multi-statement API calls by default. Each macro
    wraps its statements in a single EXECUTE IMMEDIATE $$ BEGIN...END; $$
    block — exactly one SQL call per hook.

  USAGE (in model config — must be single-line string in dbt-fusion):
    pre_hook="{{ log_model_start() }}"
    post_hook="{{ log_model_end() }}"

  QUERY THE LOG:
    SELECT * FROM SF_TEST.AUDIT.DBT_RUN_LOG ORDER BY started_at DESC;
#}


{% macro log_model_start() %}

    {% if execute %}

EXECUTE IMMEDIATE $$
BEGIN

    -- Ensure the audit schema exists (idempotent)
    CREATE SCHEMA IF NOT EXISTS {{ target.database }}.AUDIT;

    -- Ensure the audit log table exists (idempotent, never drops data)
    CREATE TABLE IF NOT EXISTS {{ target.database }}.AUDIT.DBT_RUN_LOG (
        run_id          VARCHAR(64)     NOT NULL,
        model_name      VARCHAR(255)    NOT NULL,
        target_schema   VARCHAR(255),
        target_env      VARCHAR(64),
        started_at      TIMESTAMP_NTZ,
        completed_at    TIMESTAMP_NTZ,
        status          VARCHAR(16),
        rows_loaded     INTEGER,
        elapsed_seconds FLOAT
    );

    -- Record that this model build has started
    INSERT INTO {{ target.database }}.AUDIT.DBT_RUN_LOG
        (run_id, model_name, target_schema, target_env, started_at, status)
    VALUES
        (
            '{{ invocation_id }}',
            '{{ this.name }}',
            '{{ this.schema }}',
            '{{ target.name }}',
            CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
            'running'
        );

END;
$$

    {% endif %}

{% endmacro %}


{% macro log_model_end() %}

    {% if execute %}

EXECUTE IMMEDIATE $$
BEGIN

    -- Stamp the run as successful, capture row count and elapsed time
    UPDATE {{ target.database }}.AUDIT.DBT_RUN_LOG
    SET
        status          = 'success',
        completed_at    = CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ,
        rows_loaded     = (SELECT COUNT(*) FROM {{ this }}),
        elapsed_seconds = DATEDIFF(
                            'second',
                            started_at,
                            CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP())::TIMESTAMP_NTZ
                          )
    WHERE run_id    = '{{ invocation_id }}'
      AND model_name = '{{ this.name }}';

END;
$$

    {% endif %}

{% endmacro %}
