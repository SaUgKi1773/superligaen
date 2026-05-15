{% macro fixture_filter(date_col='kick_off') %}
    {% if var('season', none) is not none %}
        season = {{ var('season') }}
    {% else %}
        {{ date_col }}::DATE >= current_date - interval '{{ var("lookback_days", 5) }}' day
        and {{ date_col }}::DATE <= current_date + interval '28' day
    {% endif %}
{% endmacro %}

{% macro season_filter(season_col='season') %}
    {% if var('season', none) is not none %}
        {{ season_col }} = {{ var('season') }}
    {% else %}
        {{ season_col }} = (
            select max((raw_json->>'$.league.season')::integer)
            from {{ source('bronze', 'api_football__fixtures') }}
        )
    {% endif %}
{% endmacro %}

{% macro gold_incremental_filter() %}
    {% if var('season', none) is not none %}
        date_sk between
            (select min(date_sk) from {{ ref('dim_date') }} where year = {{ var('season') }})
            and
            (select max(date_sk) from {{ ref('dim_date') }} where year = {{ var('season') + 1 }})
    {% else %}
        date_sk >= cast(strftime('%Y%m%d', current_date - interval '{{ var("lookback_days", 5) }}' day) as integer)
        and date_sk <= cast(strftime('%Y%m%d', current_date + interval '28' day) as integer)
    {% endif %}
{% endmacro %}
