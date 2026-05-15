-- Halftime goals can never exceed fulltime goals — physics, not an API choice.
-- Any row here means the score JSON was corrupted or misread during ingestion.
SELECT
    fixture_id,
    goals_home,
    goals_away,
    score_ht_home,
    score_ht_away
FROM {{ ref('fixtures') }}
WHERE status_short IN ('FT', 'AET', 'PEN')
  AND score_ht_home IS NOT NULL
  AND score_ht_away IS NOT NULL
  AND (
      score_ht_home > goals_home
      OR score_ht_away > goals_away
  )
