-- Every match in the fact table must have exactly 2 rows: one home, one away.
-- A broken UNION ALL or a failed incremental merge would violate this.
SELECT
    match_sk,
    count(*) AS row_count
FROM {{ ref('fct_match_results') }}
WHERE match_sk > 0
GROUP BY match_sk
HAVING count(*) != 2
