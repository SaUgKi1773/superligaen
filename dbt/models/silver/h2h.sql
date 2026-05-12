{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='id'
) }}

SELECT
    id,
    (raw_json->>'league_id')::INTEGER     AS league_id,
    (raw_json->>'season_id')::INTEGER     AS season_id,
    (raw_json->>'stage_id')::INTEGER      AS stage_id,
    (raw_json->>'round_id')::INTEGER      AS round_id,
    (raw_json->>'venue_id')::INTEGER      AS venue_id,
    (raw_json->>'state_id')::INTEGER      AS state_id,
    raw_json->>'name'                     AS name,
    (raw_json->>'starting_at')::TIMESTAMP AS starting_at,
    raw_json->>'result_info'              AS result_info,
    raw_json->>'leg'                      AS leg,
    (raw_json->>'length')::INTEGER        AS length,
    (raw_json->>'placeholder')::BOOLEAN   AS placeholder,
    raw_json->'state'->>'developer_name'  AS state_developer_name,
    (
        SELECT (p->>'id')::INTEGER
        FROM unnest(json_transform(raw_json::VARCHAR, '{"participants": ["JSON"]}').participants) AS t(p)
        WHERE p->'meta'->>'location' = 'home'
        LIMIT 1
    ) AS home_team_id,
    (
        SELECT (p->>'id')::INTEGER
        FROM unnest(json_transform(raw_json::VARCHAR, '{"participants": ["JSON"]}').participants) AS t(p)
        WHERE p->'meta'->>'location' = 'away'
        LIMIT 1
    ) AS away_team_id,
    (
        SELECT (s->'score'->>'goals')::INTEGER
        FROM unnest(json_transform(raw_json::VARCHAR, '{"scores": ["JSON"]}').scores) AS t(s)
        WHERE s->>'description' = 'CURRENT' AND s->'score'->>'participant' = 'home'
        LIMIT 1
    ) AS home_score,
    (
        SELECT (s->'score'->>'goals')::INTEGER
        FROM unnest(json_transform(raw_json::VARCHAR, '{"scores": ["JSON"]}').scores) AS t(s)
        WHERE s->>'description' = 'CURRENT' AND s->'score'->>'participant' = 'away'
        LIMIT 1
    ) AS away_score,
    _ingested_at
FROM {{ source('bronze', 'sportmonks__h2h') }}
{% if is_incremental() %}
WHERE _ingested_at > (SELECT MAX(_ingested_at) FROM {{ this }})
{% endif %}
