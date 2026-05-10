{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['fixture_id', 'player_id', 'team_id']
    )
}}

WITH src AS (
    SELECT
        fp.fixture_id,
        fp.team_id,
        fp.player_id,
        (fp.kick_off AT TIME ZONE 'Europe/Copenhagen')::DATE AS match_date,
        fp.substitute,
        fp.minutes_played,
        fp.goals,
        fp.assists,
        fp.shots_total,
        fp.shots_on,
        fp.passes_total,
        fp.passes_key,
        fp.tackles_total,
        fp.interceptions,
        fp.duels_total,
        fp.duels_won,
        fp.yellow_cards,
        fp.red_cards,
        TRY_CAST(fp.rating AS DECIMAL) AS rating
    FROM {{ ref('fixture_players') }} fp
    WHERE fp.minutes_played > 0
),
joined AS (
    SELECT
        d.date_sk,
        COALESCE(m.match_sk,  -1) AS match_sk,
        COALESCE(p.player_sk, -1) AS player_sk,
        COALESCE(t.team_sk,   -1) AS team_sk,
        CASE WHEN src.substitute THEN 2 ELSE 1 END AS appearance_type_sk,
        src.fixture_id,
        src.player_id,
        src.team_id,
        src.minutes_played,
        src.goals,
        src.assists,
        src.shots_total,
        src.shots_on,
        src.passes_total,
        src.passes_key,
        src.tackles_total,
        src.interceptions,
        src.duels_total,
        src.duels_won,
        src.yellow_cards,
        src.red_cards,
        src.rating
    FROM src
    JOIN      {{ ref('dim_date')            }} d ON d.date      = src.match_date
    LEFT JOIN {{ ref('dim_match')           }} m ON m.match_id  = src.fixture_id
    LEFT JOIN {{ ref('dim_player')          }} p ON p.player_id = src.player_id
    LEFT JOIN {{ ref('dim_team')            }} t ON t.team_id   = src.team_id
)
SELECT * FROM joined
{% if is_incremental() %}
WHERE {{ gold_incremental_filter() }}
{% endif %}
