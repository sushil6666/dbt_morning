{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_05']
) }}

{#
  Row Access Policy demo — attach_row_access_policy() shown below but requires
  the policy to be pre-created by a Snowflake admin before the post_hook runs.

  To activate once 'haunt_zone_policy' exists in your Snowflake account:
    config(post_hook="{{ attach_row_access_policy('haunt_zone_policy', 'zone_assignment') }}")

  Create the policy in Snowflake first:
    CREATE OR REPLACE ROW ACCESS POLICY haunt_zone_policy
    AS (zone_assignment VARCHAR) RETURNS BOOLEAN ->
      CURRENT_ROLE() IN ('SYSADMIN') OR zone_assignment = CURRENT_USER();
#}

SELECT
    employee_id,
    full_name,
    department,
    role,
    zone_assignment,
    hire_date,
    hourly_rate
FROM {{ ref('dim_employees') }}
