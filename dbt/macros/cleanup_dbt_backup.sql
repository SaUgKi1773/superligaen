{% macro cleanup_dbt_backup() %}
{% if config.get('materialized') in ('table', 'incremental') %}
DROP TABLE IF EXISTS {{ this.schema }}.{{ this.identifier }}__dbt_backup
{% endif %}
{% endmacro %}
