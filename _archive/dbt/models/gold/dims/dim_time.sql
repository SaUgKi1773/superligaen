{{
    config(
        materialized='table',
        schema='gold'
    )
}}

SELECT hour::INTEGER AS time_sk,
       hour::INTEGER AS hour,
       CASE
           WHEN hour BETWEEN 6  AND 11 THEN 'Morning'
           WHEN hour BETWEEN 12 AND 17 THEN 'Afternoon'
           WHEN hour BETWEEN 18 AND 23 THEN 'Evening'
           ELSE 'Night'
       END           AS period_of_day
FROM generate_series(0, 23) t(hour)
UNION ALL
SELECT -1, NULL, 'Unknown Period Of Day'
UNION ALL
SELECT -2, NULL, 'Not Applicable Period Of Day'
