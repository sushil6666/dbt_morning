{{
    config(
        materialized = 'iceberg_table',
        tags         = ['macro_demo', 'demo_19', 'custom_materialization'],
        meta         = {
            'external_volume': 'SNOWFLAKE_MANAGED',
            'base_location'  : 'haunt_analytics/ticket_sales/',
            'catalog'        : 'SNOWFLAKE'
        }
    )
}}
/*
  demo_19_iceberg_table
  ----------------------
  Tests the custom `iceberg_table` materialization (macros/materializations/snowflake/iceberg_table.sql).

  PREREQUISITES (Snowflake admin must complete before running this model):
  -------------------------------------------------------------------------
  1. Create an external volume pointing to S3 / Azure / GCS:

      CREATE EXTERNAL VOLUME my_iceberg_volume
          STORAGE_LOCATIONS = (
              (
                  NAME                 = 'my-s3-us-east-1'
                  STORAGE_PROVIDER     = 'S3'
                  STORAGE_BASE_URL     = 's3://your-bucket/iceberg/'
                  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::123456789:role/snowflake-iceberg-role'
              )
          );

  2. Grant usage to the dbt role:
      GRANT USAGE ON EXTERNAL VOLUME my_iceberg_volume TO ROLE <dbt_role>;

  Until those prerequisites exist this model will fail with:
      "External volume 'MY_ICEBERG_VOLUME' does not exist."

  -------------------------------------------------------------------------
  The model selects a ticket-sales summary — a realistic Iceberg use case
  because Iceberg tables are suited for large, append-heavy analytical data
  that must be queryable from external engines (Spark, Trino, Athena, etc.).
*/

SELECT
    transaction_id,
    customer_id,
    visit_date,
    category,
    item_name,
    quantity,
    unit_price,
    total_amount,
    payment_method,
    location
FROM {{ ref('fct_sales') }}
