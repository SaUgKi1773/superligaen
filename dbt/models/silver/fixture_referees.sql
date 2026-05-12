SELECT
    (ref->>'id')::INTEGER              AS id,
    f.id                               AS fixture_id,
    (ref->>'referee_id')::INTEGER      AS referee_id,
    (ref->>'type_id')::INTEGER         AS type_id,
    ref->'referee'->>'common_name'     AS referee_common_name,
    ref->'referee'->>'firstname'       AS referee_firstname,
    ref->'referee'->>'lastname'        AS referee_lastname,
    ref->'referee'->>'name'            AS referee_name,
    ref->'referee'->>'display_name'    AS referee_display_name,
    ref->'referee'->>'image_path'      AS referee_image_path
FROM {{ source('bronze', 'sportmonks__fixtures') }} AS f,
unnest(json_transform(f.raw_json::VARCHAR, '{"referees": ["JSON"]}').referees) AS t(ref)
WHERE json_array_length(json_extract(f.raw_json::VARCHAR, '$.referees')) > 0
