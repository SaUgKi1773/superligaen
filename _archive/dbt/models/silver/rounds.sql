{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['season', 'league_id', 'round_name']
    )
}}

SELECT
    season,
    league_id,
    UNNEST(raw_json::VARCHAR[]) AS round_name,
    ingested_at
FROM {{ source('bronze', 'api_football__rounds') }}
{% if is_incremental() %}
WHERE {{ season_filter() }}
{% endif %}
