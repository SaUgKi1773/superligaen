{% macro gold_incremental_filter(lookback_days=var('incremental_days_back', 7)) %}
    date_sk >= CAST(STRFTIME(CURRENT_DATE - INTERVAL '{{ lookback_days }}' day, '%Y%m%d') AS INTEGER)
{% endmacro %}
