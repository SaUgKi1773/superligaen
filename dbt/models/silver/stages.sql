SELECT
    id,
    (raw_json->>'league_id')::INTEGER          AS league_id,
    (raw_json->>'season_id')::INTEGER          AS season_id,
    (raw_json->>'type_id')::INTEGER            AS type_id,
    (raw_json->>'tie_breaker_rule_id')::INTEGER AS tie_breaker_rule_id,
    raw_json->>'name'                           AS name,
    (raw_json->>'sort_order')::INTEGER          AS sort_order,
    (raw_json->>'finished')::BOOLEAN            AS finished,
    (raw_json->>'is_current')::BOOLEAN          AS is_current,
    (raw_json->>'starting_at')::DATE            AS starting_at,
    (raw_json->>'ending_at')::DATE              AS ending_at,
    (raw_json->>'games_in_current_week')::BOOLEAN AS games_in_current_week
FROM {{ source('bronze', 'sportmonks__stages') }}
