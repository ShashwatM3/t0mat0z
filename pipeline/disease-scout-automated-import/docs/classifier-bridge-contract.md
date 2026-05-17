# Classifier Bridge Contract

Any teammate classifier can replace the current local proxy if it implements this contract.

## Endpoint

```text
POST /api/scout/analyze
Content-Type: application/json
```

## Request

Required:

- `observation_id`
- `worker_id`
- `crop`
- `zone`
- `capture_source`
- `upload_filename`
- `upload_size_bytes`
- `upload_mime_type`
- `report_channel`
- `wearer_note`
- `image_data_url`

`image_data_url` must be a base64 `data:image/...` URL unless the custom bridge explicitly documents a binary upload replacement.

See `examples/analyze-request.example.json`.

## Response

Return:

```json
{
  "observation": {}
}
```

`observation` must match `schemas/DiseaseScoutObservation.schema.json`.

See `examples/analyze-response.example.json`.

## Required Safety Behavior

- No pesticide, chemical, removal, or treatment recommendation.
- No final diagnosis claim.
- Use uncertainty when evidence is weak.
- Always provide one concrete next check.
- Preserve the image/capture metadata enough for supervisor review.

## One-Line Wearer Summary

After the response, compress the observation to:

```text
Disease Scout: {possible_disease}. Confidence {confidence}. Next check: {next_check}
```

Keep it short enough for audio.
