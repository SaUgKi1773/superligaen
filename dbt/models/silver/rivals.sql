SELECT
    id,
    (raw_json->>'team_id')::INTEGER  AS team_id,
    (raw_json->>'rival_id')::INTEGER AS rival_id,
    (raw_json->>'sport_id')::INTEGER AS sport_id
FROM {{ source('bronze', 'sportmonks__rivals') }}
