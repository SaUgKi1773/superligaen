SELECT
    ROW_NUMBER() OVER (ORDER BY id) AS referee_sk,
    id                              AS referee_id,
    common_name                     AS referee_common_name,
    firstname                       AS referee_firstname,
    lastname                        AS referee_lastname,
    display_name                    AS referee_display_name,
    image_path                      AS referee_image_path
FROM {{ ref('referees') }}
WHERE id IS NOT NULL
UNION ALL SELECT -1, NULL, 'Unknown Referee',        NULL, NULL, NULL, NULL
UNION ALL SELECT -2, NULL, 'Not Applicable Referee', NULL, NULL, NULL, NULL
