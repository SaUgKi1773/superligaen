{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['season', 'league_id', 'player_id', 'fixture_id']
    )
}}

SELECT
    season,
    league_id,
    (elem->>'$.player.id')::INTEGER          AS player_id,
    elem->>'$.player.name'                   AS player_name,
    elem->>'$.player.photo'                  AS player_photo,
    elem->>'$.player.type'                   AS injury_type,
    elem->>'$.player.reason'                 AS injury_reason,
    (elem->>'$.team.id')::INTEGER            AS team_id,
    elem->>'$.team.name'                     AS team_name,
    elem->>'$.team.logo'                     AS team_logo,
    (elem->>'$.fixture.id')::INTEGER         AS fixture_id,
    elem->>'$.fixture.timezone'              AS fixture_timezone,
    (elem->>'$.fixture.date')::TIMESTAMPTZ   AS fixture_date,
    (elem->>'$.fixture.timestamp')::BIGINT   AS fixture_timestamp,
    (elem->>'$.league.id')::INTEGER          AS league_id_json,
    (elem->>'$.league.season')::INTEGER      AS season_json,
    elem->>'$.league.name'                   AS league_name,
    elem->>'$.league.country'                AS league_country,
    elem->>'$.league.logo'                   AS league_logo,
    elem->>'$.league.flag'                   AS league_flag,
    ingested_at
FROM {{ source('bronze', 'api_football__injuries') }},
UNNEST(raw_json::JSON[]) AS t(elem)
{% if is_incremental() %}
WHERE {{ season_filter() }}
{% endif %}
