SELECT
    id,
    (raw_json->>'player_id')::INTEGER            AS player_id,
    (raw_json->>'type_id')::INTEGER              AS type_id,
    (raw_json->>'from_team_id')::INTEGER         AS from_team_id,
    (raw_json->>'to_team_id')::INTEGER           AS to_team_id,
    (raw_json->>'position_id')::INTEGER          AS position_id,
    (raw_json->>'detailed_position_id')::INTEGER AS detailed_position_id,
    (raw_json->>'date')::DATE                    AS transfer_date,
    (raw_json->>'career_ended')::BOOLEAN         AS career_ended,
    (raw_json->>'completed')::BOOLEAN            AS completed,
    (raw_json->>'amount')::INTEGER               AS amount,
    raw_json->'player'->>'common_name'           AS player_common_name,
    raw_json->'player'->>'display_name'          AS player_display_name,
    raw_json->'player'->>'image_path'            AS player_image_path,
    raw_json->'fromteam'->>'name'               AS from_team_name,
    raw_json->'toteam'->>'name'                 AS to_team_name,
    raw_json->'type'->>'name'                   AS transfer_type
FROM {{ source('bronze', 'sportmonks__transfers') }}
