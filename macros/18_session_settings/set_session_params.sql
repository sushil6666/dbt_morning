{#
  set_session_params(timezone, week_start, use_cached_result)
  -----------------------------------------------------------------------
  Pre-hook macro: applies a consistent bundle of Snowflake session
  parameters before a model runs.

  WHY A MACRO OVER INLINE SQL:
    Inline ALTER SESSION strings work, but scatter the parameter choices
    across every model file. A shared macro means one change propagates
    to every model that calls it — and documents the "why" in one place.

  PARAMETERS:
    timezone          (string)  — Snowflake IANA timezone name.
                                  Default 'UTC'. Use 'America/Chicago' etc.
    week_start        (int)     — First day of the week.
                                  0 = Sunday (Snowflake default / US convention)
                                  1 = Monday (ISO 8601 / European convention)
    use_cached_result (bool)    — Whether Snowflake may return cached results.
                                  False forces a live re-execution every run.
                                  Critical for financial/compliance models.

  SNOWFLAKE NOTE:
    Session parameters apply to the current connection only. dbt opens a
    fresh connection per model thread, so changes made here never bleed
    into other models running in parallel.

  USAGE (in model config — must be single-line string in dbt-fusion):
    pre_hook="{{ set_session_params(timezone='UTC', week_start=1, use_cached_result=false) }}"

  RESET:
    Session params revert automatically when the connection closes after
    the model finishes. An explicit post_hook reset is only needed when
    two models share a persistent connection (rare in dbt).
#}

{% macro set_session_params(timezone='UTC', week_start=1, use_cached_result=false) %}

    {% if execute and target.type == 'snowflake' %}

EXECUTE IMMEDIATE $$
BEGIN
    ALTER SESSION SET TIMEZONE             = '{{ timezone }}';
    ALTER SESSION SET WEEK_START           = {{ week_start }};
    ALTER SESSION SET USE_CACHED_RESULT    = {{ 'TRUE' if use_cached_result else 'FALSE' }};
END;
$$

    {% endif %}

{% endmacro %}
