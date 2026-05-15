{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='fixture_id'
    )
}}

WITH src AS (
    SELECT
        l.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER         AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER     AS season,
        (tl->>'$.team.id')::INTEGER                   AS team_id,
        tl->>'$.team.name'                            AS team_name,
        tl->>'$.team.logo'                            AS team_logo,
        (tl->'$.team.colors')                         AS team_colors,
        tl->>'$.formation'                            AS formation,
        (tl->>'$.coach.id')::INTEGER                  AS coach_id,
        tl->>'$.coach.name'                           AS coach_name,
        tl->>'$.coach.photo'                          AS coach_photo,
        (p->>'$.player.id')::INTEGER                  AS player_id,
        p->>'$.player.name'                           AS player_name,
        (p->>'$.player.number')::INTEGER              AS player_number,
        p->>'$.player.pos'                            AS player_position,
        p->>'$.player.grid'                           AS player_grid,
        true                                          AS is_starter,
        l.ingested_at
    FROM {{ source('bronze', 'api_football__fixture_lineups') }} l
    JOIN {{ source('bronze', 'api_football__fixtures') }} f USING (fixture_id),
    UNNEST(l.raw_json::JSON[]) AS t1(tl),
    UNNEST((tl->'$.startXI')::JSON[]) AS t2(p)
    WHERE (p->>'$.player.id') IS NOT NULL
    UNION ALL
    SELECT
        l.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER         AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER     AS season,
        (tl->>'$.team.id')::INTEGER                   AS team_id,
        tl->>'$.team.name'                            AS team_name,
        tl->>'$.team.logo'                            AS team_logo,
        (tl->'$.team.colors')                         AS team_colors,
        tl->>'$.formation'                            AS formation,
        (tl->>'$.coach.id')::INTEGER                  AS coach_id,
        tl->>'$.coach.name'                           AS coach_name,
        tl->>'$.coach.photo'                          AS coach_photo,
        (p->>'$.player.id')::INTEGER                  AS player_id,
        p->>'$.player.name'                           AS player_name,
        (p->>'$.player.number')::INTEGER              AS player_number,
        p->>'$.player.pos'                            AS player_position,
        NULL                                          AS player_grid,
        false                                         AS is_starter,
        l.ingested_at
    FROM {{ source('bronze', 'api_football__fixture_lineups') }} l
    JOIN {{ source('bronze', 'api_football__fixtures') }} f USING (fixture_id),
    UNNEST(l.raw_json::JSON[]) AS t1(tl),
    UNNEST((tl->'$.substitutes')::JSON[]) AS t2(p)
    WHERE (p->>'$.player.id') IS NOT NULL
)
SELECT * FROM src
{% if is_incremental() %}
WHERE {{ fixture_filter('kick_off') }}
{% endif %}
