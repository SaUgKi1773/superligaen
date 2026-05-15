-- Every fixture must have exactly 2 participants: one home, one away.
-- Fewer means a team went missing from the API response.
SELECT fixture_id, count(*) AS participant_count
FROM {{ ref('fixture_participants') }}
GROUP BY fixture_id
HAVING count(*) != 2
