# Pipeline Agent Instructions

## Mission

Port or maintain the Disease Scout automated import pipeline:

```text
image capture/import -> automated ingest -> classifier bridge -> wearer result -> supervisor packet
```

## Boundaries

- Work inside `pipeline/disease-scout-automated-import/`, `scripts/auto-import-watch.ps1`, and the documented app/server bridge unless explicitly told otherwise.
- Keep the output disease-only.
- Never recommend treatment, pesticides, removal, or final diagnosis.
- Never commit API keys, `.env` files, screenshots with keys, local database files, or private credentials.
- Do not claim direct Meta web-gallery image access unless tested and sourced.
- Do not claim in-lens UI on ordinary Ray-Ban Meta.

## Required First Reads

1. `README.md`
2. `docs/architecture.md`
3. `docs/integration-guide.md`
4. `docs/classifier-bridge-contract.md`
5. `config/pipeline.example.json`
6. `schemas/DiseaseScoutObservation.schema.json`

## Implementation Rules

- Make all integration variables editable through config or environment variables.
- Keep classifier providers swappable.
- Keep the one-line wearer result short enough for audio:
  - possible disease or concern;
  - confidence/evidence quality;
  - one next check.
- Save full structured output for supervisor/dashboard use.
- If using `local-fast`, label it as fast triage, not a full model.
- If using `live`, measure latency and provide a fallback.

## Verification

Run from repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\pipeline\disease-scout-automated-import\scripts\smoke-test-local-fast.ps1
```

For server/app bridge changes:

```powershell
cd app
npm test
```

For config/schema changes:

```powershell
node -e "const fs=require('fs'); for (const f of process.argv.slice(1)) JSON.parse(fs.readFileSync(f,'utf8')); console.log('json_ok')" .\pipeline\disease-scout-automated-import\config\pipeline.example.json .\pipeline\disease-scout-automated-import\schemas\DiseaseScoutObservation.schema.json
```

Mark hardware-dependent pieces as blocked unless actually tested with the target glasses and phone.
