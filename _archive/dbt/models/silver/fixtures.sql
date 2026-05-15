{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='fixture_id'
    )
}}

WITH venue_lookup AS (
    SELECT
        (elem->>'$.name')::VARCHAR    AS venue_name,
        MIN((elem->>'$.id')::INTEGER) AS venue_id
    FROM {{ source('bronze', 'api_football__venues') }} v,
    UNNEST(v.raw_json::JSON[]) AS t(elem)
    WHERE elem->>'$.id' IS NOT NULL
    GROUP BY (elem->>'$.name')::VARCHAR
),
home_team_venue AS (
    SELECT DISTINCT ON (team_id)
        (elem->>'$.team.id')::INTEGER  AS team_id,
        (elem->>'$.venue.id')::INTEGER AS venue_id
    FROM {{ source('bronze', 'api_football__teams') }},
    UNNEST(raw_json::JSON[]) AS t(elem)
    WHERE (elem->>'$.venue.id') IS NOT NULL
    ORDER BY team_id, season DESC
),
src AS (
    SELECT
        (raw_json->>'$.fixture.id')::INTEGER          AS fixture_id,
        CASE TRIM(SPLIT_PART(raw_json->>'$.fixture.referee', ',', 1))
            WHEN 'A. Uslu'                THEN 'Aydin Uslu'
            WHEN 'C. Theouli'             THEN 'Chrysovalantis Theouli'
            WHEN 'F. Svendsen'            THEN 'Frederik Svendsen'
            WHEN 'J. A. Sundberg'         THEN 'Jacob A. Sundberg'
            WHEN 'J. Sundberg'            THEN 'Jacob A. Sundberg'
            WHEN 'J. Burchardt'           THEN 'Jorgen Daugbjerg Burchardt'
            WHEN 'J. Hansen'              THEN 'Jonas Hansen'
            WHEN 'J. Karlsen'             THEN 'Jacob Karlsen'
            WHEN 'J. Kehlet'              THEN 'Jakob Kehlet'
            WHEN 'J. Maae'                THEN 'Jens Maae'
            WHEN 'K. Athanasiou'          THEN 'Kyriakos Athanasiou'
            WHEN 'L. Graagaard'           THEN 'Lasse Laebel Graagaard'
            WHEN 'M. Antoniou'            THEN 'Menelaos Antoniou'
            WHEN 'M. Kristoffersen'       THEN 'Mads Kristoffer Kristoffersen'
            WHEN 'M. Krogh'               THEN 'Morten Krogh'
            WHEN 'M. Redder'              THEN 'Mikkel Redder'
            WHEN 'M. Tykgaard'            THEN 'Michael Tykgaard'
            WHEN 'P. Kjærsgaard-Andersen' THEN 'Peter Kjaersgaard-Andersen'
            WHEN 'S. Putros'              THEN 'Sandi Putros'
            WHEN 'S. Rasmussen'           THEN 'Simon Duerland Rasmussen'
            ELSE TRIM(SPLIT_PART(raw_json->>'$.fixture.referee', ',', 1))
        END                                           AS referee,
        raw_json->>'$.fixture.timezone'               AS timezone,
        (raw_json->>'$.fixture.date')::TIMESTAMPTZ    AS kick_off,
        (raw_json->>'$.fixture.timestamp')::BIGINT    AS kick_off_ts,
        (raw_json->>'$.fixture.periods.first')::INTEGER  AS period_first,
        (raw_json->>'$.fixture.periods.second')::INTEGER AS period_second,
        COALESCE(
            (raw_json->>'$.fixture.venue.id')::INTEGER,
            vl.venue_id,
            htv.venue_id
        )                                             AS venue_id,
        raw_json->>'$.fixture.venue.name'             AS venue_name,
        raw_json->>'$.fixture.venue.city'             AS venue_city,
        raw_json->>'$.fixture.status.long'            AS status_long,
        raw_json->>'$.fixture.status.short'           AS status_short,
        (raw_json->>'$.fixture.status.elapsed')::INTEGER AS status_elapsed,
        (raw_json->>'$.fixture.status.extra')::INTEGER   AS status_extra,
        (raw_json->>'$.league.id')::INTEGER           AS league_id,
        raw_json->>'$.league.name'                    AS league_name,
        raw_json->>'$.league.country'                 AS league_country,
        raw_json->>'$.league.logo'                    AS league_logo,
        raw_json->>'$.league.flag'                    AS league_flag,
        (raw_json->>'$.league.season')::INTEGER       AS season,
        raw_json->>'$.league.round'                   AS league_round,
        (raw_json->>'$.league.standings')::BOOLEAN    AS league_standings,
        (raw_json->>'$.teams.home.id')::INTEGER       AS home_team_id,
        raw_json->>'$.teams.home.name'                AS home_team_name,
        raw_json->>'$.teams.home.logo'                AS home_team_logo,
        (raw_json->>'$.teams.home.winner')::BOOLEAN   AS home_team_winner,
        (raw_json->>'$.teams.away.id')::INTEGER       AS away_team_id,
        raw_json->>'$.teams.away.name'                AS away_team_name,
        raw_json->>'$.teams.away.logo'                AS away_team_logo,
        (raw_json->>'$.teams.away.winner')::BOOLEAN   AS away_team_winner,
        (raw_json->>'$.goals.home')::INTEGER          AS goals_home,
        (raw_json->>'$.goals.away')::INTEGER          AS goals_away,
        (raw_json->>'$.score.halftime.home')::INTEGER  AS score_ht_home,
        (raw_json->>'$.score.halftime.away')::INTEGER  AS score_ht_away,
        (raw_json->>'$.score.fulltime.home')::INTEGER  AS score_ft_home,
        (raw_json->>'$.score.fulltime.away')::INTEGER  AS score_ft_away,
        (raw_json->>'$.score.extratime.home')::INTEGER AS score_et_home,
        (raw_json->>'$.score.extratime.away')::INTEGER AS score_et_away,
        (raw_json->>'$.score.penalty.home')::INTEGER   AS score_pen_home,
        (raw_json->>'$.score.penalty.away')::INTEGER   AS score_pen_away,
        ingested_at
    FROM {{ source('bronze', 'api_football__fixtures') }}
    LEFT JOIN venue_lookup vl  ON vl.venue_name = (raw_json->>'$.fixture.venue.name')::VARCHAR
    LEFT JOIN home_team_venue htv ON htv.team_id = (raw_json->>'$.teams.home.id')::INTEGER
)
SELECT * FROM src
{% if is_incremental() %}
WHERE {{ fixture_filter('kick_off') }}
{% endif %}
