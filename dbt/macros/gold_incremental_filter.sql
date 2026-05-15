{% macro gold_incremental_filter(lookback_days=5) %}
    date_sk >= CAST(STRFTIME(CURRENT_DATE - INTERVAL '{{ lookback_days }}' day, '%Y%m%d') AS INTEGER)
{% endmacro %}
