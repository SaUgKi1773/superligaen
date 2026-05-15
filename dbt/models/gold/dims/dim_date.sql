WITH season_ranges AS (
    SELECT
        name          AS season,
        starting_at::DATE AS season_start,
        ending_at::DATE   AS season_end
    FROM {{ ref('seasons') }}
),
current_season AS (
    SELECT season
    FROM season_ranges
    WHERE CURRENT_DATE BETWEEN season_start AND season_end
)
SELECT
    (year(d) * 10000 + month(d) * 100 + day(d))::INTEGER AS date_sk,
    d::DATE                                               AS date,
    year(d)::INTEGER                                      AS year,
    'Q' || quarter(d)::INTEGER                            AS quarter,
    month(d)::INTEGER                                     AS month,
    monthname(d)                                          AS month_name,
    weekofyear(d)::INTEGER                                AS week_number,
    isodow(d)::INTEGER                                    AS day_of_week,
    dayname(d)                                            AS day_name,
    CASE WHEN isodow(d) IN (6, 7) THEN 'Yes' ELSE 'No' END AS is_weekend,
    LEFT(sr.season, 4) || '/' || RIGHT(sr.season, 2)      AS season,
    sr.season = (SELECT season FROM current_season)        AS is_current_season
FROM generate_series(DATE '2010-01-01', DATE '2030-12-31', INTERVAL '1 day') t(d)
LEFT JOIN season_ranges sr ON d::DATE BETWEEN sr.season_start AND sr.season_end
