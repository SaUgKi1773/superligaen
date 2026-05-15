{{
    config(
        materialized='table',
        schema='gold'
    )
}}

WITH season_dates AS (
    SELECT
        (s->>'$.year')::INTEGER AS season_year,
        (s->>'$.start')::DATE   AS season_start,
        (s->>'$.end')::DATE     AS season_end,
        (s->>'$.year')::VARCHAR || '/' || RIGHT(((s->>'$.year')::INTEGER + 1)::VARCHAR, 2) AS season
    FROM {{ ref('leagues') }},
    UNNEST(seasons::JSON[]) AS t(s)
    WHERE league_id = 119
)
SELECT
    strftime('%Y%m%d', d)::INTEGER           AS date_sk,
    d::DATE                                  AS date,
    EXTRACT(year    FROM d)::INTEGER         AS year,
    'Q' || EXTRACT(quarter FROM d)::INTEGER  AS quarter,
    EXTRACT(month   FROM d)::INTEGER         AS month,
    monthname(d)                             AS month_name,
    weekofyear(d)::INTEGER                   AS week_number,
    isodow(d)::INTEGER                       AS day_of_week,
    dayname(d)                               AS day_name,
    CASE WHEN isodow(d) IN (6, 7) THEN 'Yes' ELSE 'No' END AS is_weekend,
    sd.season
FROM generate_series(DATE '2020-01-01', DATE '2030-12-31', INTERVAL '1 day') t(d)
LEFT JOIN season_dates sd ON d::DATE BETWEEN sd.season_start AND sd.season_end
