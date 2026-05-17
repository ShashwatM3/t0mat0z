# Disease Scout Automated Import Pipeline

This folder packages the current Disease Scout Memory pipeline for a teammate or agent to port into another implementation.

The goal is simple:

```text
capture/import image -> detect newest image -> classify/triage -> return one action to wearer -> save supervisor packet
```

## Current Best Demo Path

Use the fast local path for live wearer feedback:

```text
photo lands in watched folder -> auto-import watcher -> local-fast triage -> audio/notification -> saved JSON
```

Use the live model path for proof receipts and richer analysis:

```text
photo lands in watched folder -> auto-import watcher -> /api/scout/analyze -> LLM classifier -> saved JSON
```

## Hardware Truth

- Best final path: DAT `capturePhoto` returns image bytes directly to the app.
- Fast fallback: Meta AI app imports the glasses photo, then Android/gallery watcher or sync-folder watcher detects it.
- Browser file picker is only semi-automated and should not be called fully automated.
- Ordinary Ray-Ban Meta return path is audio or phone notification. Do not claim lens display.
- Meta Ray-Ban Display can use a Web App/display path only if tested on that hardware.

## Folder Map

| Path | Purpose |
| --- | --- |
| `AGENTS.md` | Instructions for an agent working only on this pipeline folder. |
| `config/pipeline.example.json` | Main editable pipeline variables. |
| `config/local.env.example.ps1` | Environment variable examples for API/model providers. |
| `docs/architecture.md` | Pipeline architecture and mode choices. |
| `docs/integration-guide.md` | How to port into a teammate process. |
| `docs/variables.md` | Every editable variable and where it maps. |
| `docs/classifier-bridge-contract.md` | Request/response contract for custom classifiers. |
| `docs/meta-glasses-import-paths.md` | DAT, Android/gallery, and sync-folder options. |
| `docs/return-to-wearer.md` | Audio, notification, and display result options. |
| `docs/demo-runbook.md` | Fast demo sequence and fallback. |
| `docs/acceptance-checklist.md` | What must pass before claiming the pipeline works. |
| `schemas/DiseaseScoutObservation.schema.json` | Canonical output schema. |
| `examples/` | Example request, response, and summary. |
| `scripts/run-auto-import-watch.ps1` | Config-driven wrapper around the repo watcher. |
| `scripts/smoke-test-local-fast.ps1` | Local smoke test for automated import mechanics. |

## Quick Start

From the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\pipeline\disease-scout-automated-import\scripts\smoke-test-local-fast.ps1
```

Start continuous fast demo mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\pipeline\disease-scout-automated-import\scripts\run-auto-import-watch.ps1 -Watch -Provider local-fast -SpeakResult
```

Start live model mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\pipeline\disease-scout-automated-import\scripts\run-auto-import-watch.ps1 -Watch -Provider live -SpeakResult
```

## Current Measurements

| Path | Measured result |
| --- | --- |
| Live browser upload through `codex-cli` | 11115 ms |
| Live model max in latency audit | 14405 ms |
| Automated folder import through `codex-cli` | 45455 ms |
| Automated folder import through `local-fast` | 188 ms |

Decision: use `local-fast` for live wearer feedback and keep live model receipts for proof.

## API Key Setup

Use environment variables in the server process only:

```powershell
$env:DISEASE_SCOUT_MODEL_PROVIDER = "openai"
$env:OPENAI_API_KEY = "<local key>"
```

or:

```powershell
$env:DISEASE_SCOUT_MODEL_PROVIDER = "gemini"
$env:GEMINI_API_KEY = "<local key>"
```

Do not commit keys. Do not put keys in browser code.
