{#
  apply_constraints(primary_key, unique_keys, not_null_columns,
                    fk_columns, fk_ref_models, fk_ref_columns)
  -----------------------------------------------------------------------
  Post-hook macro: applies DDL constraints to the materialised table.
  All ALTER TABLE statements are wrapped in a single
  EXECUTE IMMEDIATE $$ BEGIN ... END; $$ block so dbt sends one SQL
  call to Snowflake (which rejects multi-statement API calls by default).

  WHY POST-HOOK, NOT PRE-HOOK:
    The table must already exist before ALTER TABLE can run. post_hook fires
    after dbt writes the table — the only valid window.

  SNOWFLAKE CONSTRAINT BEHAVIOR — CRITICAL:
    PRIMARY KEY, UNIQUE, NOT NULL, and FOREIGN KEY are metadata-only.
    Snowflake stores them in information_schema but never rejects writes
    that violate them. Pair with dbt tests for real enforcement.
    BI tools (Tableau, Power BI, Looker) read information_schema
    constraints to auto-infer join paths.

  FOREIGN KEY NOTE:
    Snowflake requires the referenced column to already have a PRIMARY KEY
    or UNIQUE constraint. FK creation is wrapped in its own BEGIN...EXCEPTION
    block so a missing upstream constraint produces a logged warning rather
    than a hard failure. Add constraints to dimension models first for full
    FK support (e.g. apply_constraints(primary_key='customer_id') on
    dim_customers).

  PARAMETERS:
    primary_key      (string)       — single column for the PK constraint
    unique_keys      (list[str])    — columns that each get UNIQUE
    not_null_columns (list[str])    — columns that get SET NOT NULL
    fk_columns       (list[str])    — FK source columns (parallel lists)
    fk_ref_models    (list[str])    — dbt model names for FK targets
    fk_ref_columns   (list[str])    — column names in the FK target tables

  PARALLEL LIST CONVENTION:
    fk_columns[i] references fk_ref_models[i].fk_ref_columns[i].
    All three lists must have the same length.

  USAGE (in model config — must be single-line string in dbt-fusion):
    post_hook="{{ apply_constraints(primary_key='sale_id', unique_keys=['ticket_id'], not_null_columns=['sale_id','customer_id'], fk_columns=['customer_id'], fk_ref_models=['dim_customers'], fk_ref_columns=['customer_id']) }}"
#}

{% macro apply_constraints(
    primary_key      = none,
    unique_keys      = [],
    not_null_columns = [],
    fk_columns       = [],
    fk_ref_models    = [],
    fk_ref_columns   = []
) %}

    {# Only generate SQL during dbt run — skip parse/compile passes #}
    {% if execute %}

        {% if target.type != 'snowflake' %}
            {{ exceptions.warn("apply_constraints: Snowflake-only macro. Skipping on " ~ target.type ~ ".") }}

        {% else %}

            {# Collect all ALTER TABLE statements as a list, then emit them  #}
            {# inside a single EXECUTE IMMEDIATE BEGIN...END block.          #}
            {# Snowflake rejects multi-statement API calls by default; this  #}
            {# pattern sends exactly one SQL call regardless of how many     #}
            {# constraints are declared.                                     #}
            {% set stmts = [] %}

            {# ---------------------------------------------------------------- #}
            {# PRIMARY KEY                                                       #}
            {# ---------------------------------------------------------------- #}
            {% if primary_key is not none %}
                {% do stmts.append(
                    "ALTER TABLE " ~ this ~ " ADD PRIMARY KEY (" ~ primary_key ~ ");"
                ) %}
            {% endif %}

            {# ---------------------------------------------------------------- #}
            {# UNIQUE — one constraint per column                               #}
            {# ---------------------------------------------------------------- #}
            {% for col in unique_keys %}
                {% do stmts.append(
                    "ALTER TABLE " ~ this ~ " ADD UNIQUE (" ~ col ~ ");"
                ) %}
            {% endfor %}

            {# ---------------------------------------------------------------- #}
            {# NOT NULL — Snowflake syntax: ALTER COLUMN ... SET NOT NULL       #}
            {# ---------------------------------------------------------------- #}
            {% for col in not_null_columns %}
                {% do stmts.append(
                    "ALTER TABLE " ~ this ~ " ALTER COLUMN " ~ col ~ " SET NOT NULL;"
                ) %}
            {% endfor %}

            {# ---------------------------------------------------------------- #}
            {# FOREIGN KEYS — each wrapped in its own EXCEPTION block.         #}
            {# Snowflake requires the referenced column to have PK or UNIQUE.  #}
            {# This gracefully skips FK creation when that constraint is absent #}
            {# rather than failing the entire model run.                        #}
            {# ---------------------------------------------------------------- #}
            {% for i in range(fk_columns | length) %}
                {% set ref_table = ref(fk_ref_models[i]) %}
                {% set fk_sql %}
BEGIN
    ALTER TABLE {{ this }}
    ADD FOREIGN KEY ({{ fk_columns[i] }})
    REFERENCES {{ ref_table }} ({{ fk_ref_columns[i] }});
EXCEPTION
    WHEN OTHER THEN
        SYSTEM$LOG('warn', 'apply_constraints: FK {{ fk_columns[i] }} -> {{ ref_table }}.{{ fk_ref_columns[i] }} skipped — referenced column has no PK/UNIQUE. Add constraints to {{ fk_ref_models[i] }} first.');
END;
                {% endset %}
                {% do stmts.append(fk_sql) %}
            {% endfor %}

            {# Emit as a single EXECUTE IMMEDIATE block #}
            {% if stmts | length > 0 %}
EXECUTE IMMEDIATE $$
BEGIN
    {{ stmts | join('\n    ') }}
END;
$$
            {% endif %}

        {% endif %}

    {% endif %}

{% endmacro %}
