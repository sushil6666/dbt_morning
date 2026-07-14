{{ config(
    materialized='view',
    tags=['macro_demo', 'demo_40', 'staging']
) }}

/*
  demo_40_generate_base_model
  ---------------------------
  PURPOSE:
    Demonstrates generating a staging-style model entirely from macro
    configuration instead of hand-writing the full SELECT each time.

  WHAT THIS MODEL DOES:
    Reads from the raw sales source, renames columns into staging-friendly names,
    derives a boolean flag expression, filters out null transaction ids, and
    appends standard audit metadata columns.
*/

{{ generate_base_model(
    source_name='raw',
    table_name='raw_sales_transactions',
    column_mapping={
        'transaction_id': 'sales_transaction_id',
        'customer_id': 'customer_id',
        'visit_date': 'visit_date',
        'category': 'product_category',
        'item_name': 'product_name',
        'quantity': 'quantity',
        'unit_price': 'unit_price',
        'total_amount': 'gross_revenue',
        'payment_method': 'payment_method',
        'location': 'location_name',
        '(customer_id is null)': 'is_guest_checkout'
    },
    where_clause='transaction_id is not null',
    add_audit_columns=True
) }}
