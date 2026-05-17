# Integration Guide

## Objective

Port this pipeline into a teammate's process without losing the core contract:

```text
image bytes in -> DiseaseScoutObservation out -> one next check to wearer
```

## Step 1 - Pick Import Surface

Choose exactly one primary path:

| Path | When to choose |
| --- | --- |
| DAT `capturePhoto` | Native integration is working. |
| Android gallery watcher | Android phone is paired to the glasses and can watch imported media. |
| Sync-folder watcher | Phone can reliably sync imported photos to laptop. |
| Manual file picker | Testing only. Do not call it fully automated. |

## Step 2 - Connect Classifier

Use the existing local proxy:

```powershell
cd app
npm run ai-server
```

or replace it with a custom bridge that implements:

```text
POST /api/scout/analyze
request: examples/analyze-request.example.json
response: examples/analyze-response.example.json
schema: schemas/DiseaseScoutObservation.schema.json
```

## Step 3 - Configure Variables

Copy and edit:

```text
config/pipeline.example.json
config/local.env.example.ps1
```

Do not edit secrets into committed files.

## Step 4 - Run Fast Import

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\pipeline\disease-scout-automated-import\scripts\run-auto-import-watch.ps1 -Watch -Provider local-fast -SpeakResult
```

Drop a test image into the configured `watchPath`. The watcher should produce:

- result JSON;
- summary text;
- optional spoken result.

## Step 5 - Run Live Bridge

Start the AI proxy and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\pipeline\disease-scout-automated-import\scripts\run-auto-import-watch.ps1 -Watch -Provider live -SpeakResult
```

Use this for proof and final-quality classifier output when latency allows.

## Step 6 - Port Into Teammate App

Replace the watched-folder step with the teammate process, but preserve:

- `image_data_url` or equivalent image bytes;
- observation metadata;
- `DiseaseScoutObservation` schema;
- one-line wearer summary;
- no treatment and no final diagnosis.

## Stop Conditions

Stop and write the blocker if:

- platform cannot expose the imported image without manual selection;
- classifier latency exceeds demo needs and no fast fallback is available;
- result cannot return to the wearer;
- output recommends treatment or final diagnosis;
- API key would need to be committed or put in browser code.
