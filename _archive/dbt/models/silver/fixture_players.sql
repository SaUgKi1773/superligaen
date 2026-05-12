{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key=['fixture_id', 'team_id', 'player_id']
    )
}}

-- CTEs pipeline each UNNEST level separately so MotherDuck can stream
-- the intermediate results rather than materialising the full nested join
-- at once, which exceeds the Pulse memory cap.
WITH teams AS (
    SELECT fixture_id, ingested_at, UNNEST(raw_json::JSON[]) AS te
    FROM {{ source('bronze', 'api_football__fixture_players') }}
),
players AS (
    SELECT fixture_id, ingested_at, te, UNNEST((te->'$.players')::JSON[]) AS pl
    FROM teams
),
stats AS (
    SELECT fixture_id, ingested_at, te, pl, UNNEST((pl->'$.statistics')::JSON[]) AS st
    FROM players
),
src AS (
    SELECT
        s.fixture_id,
        (f.raw_json->>'$.fixture.date')::TIMESTAMPTZ       AS kick_off,
        (f.raw_json->>'$.league.id')::INTEGER               AS league_id,
        (f.raw_json->>'$.league.season')::INTEGER           AS season,
        (s.te->>'$.team.id')::INTEGER                       AS team_id,
        s.te->>'$.team.name'                                AS team_name,
        s.te->>'$.team.logo'                                AS team_logo,
        (s.pl->>'$.player.id')::INTEGER                     AS player_id,
        s.pl->>'$.player.name'                              AS player_name,
        s.pl->>'$.player.photo'                             AS player_photo,
        (s.st->>'$.games.minutes')::INTEGER                 AS minutes_played,
        (s.st->>'$.games.number')::INTEGER                  AS shirt_number,
        s.st->>'$.games.position'                           AS position,
        s.st->>'$.games.rating'                             AS rating,
        (s.st->>'$.games.captain')::BOOLEAN                 AS captain,
        (s.st->>'$.games.substitute')::BOOLEAN              AS substitute,
        (s.st->>'$.offsides')::INTEGER                      AS offsides,
        (s.st->>'$.shots.total')::INTEGER                   AS shots_total,
        (s.st->>'$.shots.on')::INTEGER                      AS shots_on,
        (s.st->>'$.goals.total')::INTEGER                   AS goals,
        (s.st->>'$.goals.conceded')::INTEGER                AS goals_conceded,
        (s.st->>'$.goals.assists')::INTEGER                 AS assists,
        (s.st->>'$.goals.saves')::INTEGER                   AS saves,
        (s.st->>'$.passes.total')::INTEGER                  AS passes_total,
        (s.st->>'$.passes.key')::INTEGER                    AS passes_key,
        s.st->>'$.passes.accuracy'                          AS passes_accuracy,
        (s.st->>'$.tackles.total')::INTEGER                 AS tackles_total,
        (s.st->>'$.tackles.blocks')::INTEGER                AS tackles_blocks,
        (s.st->>'$.tackles.interceptions')::INTEGER         AS interceptions,
        (s.st->>'$.duels.total')::INTEGER                   AS duels_total,
        (s.st->>'$.duels.won')::INTEGER                     AS duels_won,
        (s.st->>'$.dribbles.attempts')::INTEGER             AS dribbles_attempts,
        (s.st->>'$.dribbles.success')::INTEGER              AS dribbles_success,
        (s.st->>'$.dribbles.past')::INTEGER                 AS dribbles_past,
        (s.st->>'$.fouls.drawn')::INTEGER                   AS fouls_drawn,
        (s.st->>'$.fouls.committed')::INTEGER               AS fouls_committed,
        (s.st->>'$.cards.yellow')::INTEGER                  AS yellow_cards,
        (s.st->>'$.cards.red')::INTEGER                     AS red_cards,
        (s.st->>'$.penalty.won')::INTEGER                   AS penalty_won,
        (s.st->>'$.penalty.committed')::INTEGER             AS penalty_committed,
        (s.st->>'$.penalty.scored')::INTEGER                AS penalty_scored,
        (s.st->>'$.penalty.missed')::INTEGER                AS penalty_missed,
        (s.st->>'$.penalty.saved')::INTEGER                 AS penalty_saved,
        s.ingested_at
    FROM stats s
    JOIN {{ source('bronze', 'api_football__fixtures') }} f USING (fixture_id)
)
SELECT * FROM src
{% if is_incremental() %}
WHERE {{ fixture_filter('kick_off') }}
{% endif %}
