SELECT
    ROW_NUMBER() OVER (ORDER BY id) AS country_sk,
    id                              AS country_id,
    continent_id,
    name                            AS country_name,
    official_name,
    fifa_name,
    iso2,
    iso3,
    flag_image_path
FROM {{ ref('core_countries') }}
WHERE id IS NOT NULL
UNION ALL SELECT -1, NULL, NULL, 'Unknown Country',        NULL, NULL, NULL, NULL, NULL
UNION ALL SELECT -2, NULL, NULL, 'Not Applicable Country', NULL, NULL, NULL, NULL, NULL
