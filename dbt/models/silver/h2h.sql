SELECT
    id,
    (raw_json->>'league_id')::INTEGER    AS league_id,
    (raw_json->>'season_id')::INTEGER    AS season_id,
    (raw_json->>'stage_id')::INTEGER     AS stage_id,
    (raw_json->>'round_id')::INTEGER     AS round_id,
    (raw_json->>'venue_id')::INTEGER     AS venue_id,
    (raw_json->>'state_id')::INTEGER     AS state_id,
    raw_json->>'name'                    AS name,
    (raw_json->>'starting_at')::TIMESTAMP AS starting_at,
    raw_json->>'result_info'             AS result_info,
    raw_json->>'leg'                     AS leg,
    (raw_json->>'length')::INTEGER       AS length,
    (raw_json->>'placeholder')::BOOLEAN  AS placeholder
FROM {{ source('bronze', 'sportmonks__h2h') }}
