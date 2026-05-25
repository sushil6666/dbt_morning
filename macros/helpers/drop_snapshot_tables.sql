{% macro drop_snapshot_tables() %}
    {% set tables = [
        'SF_TEST.snapshots.snp_customers',
        'SF_TEST.snapshots.snp_ticket_sales_history',
        'SF_TEST.snapshots.snp_visitor_feedback_changes'
    ] %}
    {% for tbl in tables %}
        {% set drop_sql %}DROP TABLE IF EXISTS {{ tbl }}{% endset %}
        {% do run_query(drop_sql) %}
        {{ log('Dropped: ' ~ tbl, info=True) }}
    {% endfor %}
{% endmacro %}
