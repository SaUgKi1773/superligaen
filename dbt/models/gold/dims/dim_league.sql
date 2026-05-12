SELECT
    ROW_NUMBER() OVER (ORDER BY id) AS league_sk,
    id                              AS league_id,
    name                            AS league_name,
    type                            AS league_type,
    image_path                      AS league_image_path
FROM {{ ref('league') }}
WHERE id IS NOT NULL
UNION ALL SELECT -1, NULL, 'Unknown League',        NULL, NULL
UNION ALL SELECT -2, NULL, 'Not Applicable League', NULL, NULL
