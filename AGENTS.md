# Disease Scout Classifier Agent Instructions

## Project Frame

- This repo is the canonical build tree for the AIFS x Meta Wearables AI AgTech Hackathon.
- Current demo concept: Disease Scout classifier.
- Optimize for a working demo, clear handoff, and truthful hardware claims.
- Do not pitch final diagnosis or treatment. Use "possible disease", "triage", "evidence quality", "next check", and "supervisor review".
- Do not recreate opportunity-lane folders. This repo should stay centered on the classifier prototype and its import/wearer-return path.

## Primary Surfaces

- `app/` - Expo web/mobile simulator and Node AI proxy.
- `scripts/auto-import-watch.ps1` - automated image import watcher for the capture-to-classifier bridge.
- `pipeline/disease-scout-automated-import/` - teammate handoff folder for porting the pipeline.
- `glasses/` and `final_docs/android-dat-checklist.md` - DAT/hardware checklist and real-device caveats.
- `final_docs/overnight/` - proof receipts from previous demo validation.

Use these surfaces for new work instead of adding broad concept folders:

- App/UI/server behavior goes in `app/`.
- Classifier import and bridge handoff work goes in `pipeline/disease-scout-automated-import/` and `scripts/auto-import-watch.ps1`.
- DAT or hardware assumptions go in `glasses/` or `final_docs/android-dat-checklist.md`.
- Demo receipts go in `final_docs/overnight/` or `final_docs/auto-import/`.

## Pipeline Integration Rules

- Start with `pipeline/disease-scout-automated-import/README.md`.
- Keep variables editable through config files or environment variables. Do not hardcode teammate API keys, URLs, model names, crop names, zones, or watch paths.
- Never put API keys in browser code, committed `.env` files, screenshots, logs, or markdown.
- A classifier bridge must accept the documented JSON request and return a `DiseaseScoutObservation` object matching `schemas/DiseaseScoutObservation.schema.json`.
- If using ordinary Ray-Ban Meta, result return is audio or phone notification through the paired device. Do not claim an in-lens UI.
- If using Meta Ray-Ban Display, a Web App/display result is allowed only after testing on MRBD hardware.
- If using the Meta AI app import fallback, treat Meta AI as photo transport only, not as the classifier.
- Fully automated import means no manual file picker in the demo loop. Use DAT `PhotoData`, an Android/gallery watcher, or a watched sync folder.

## Commands

Run from repo root unless noted:

```powershell
cd app
npm test
```

```powershell
cd app
npm run ai-server
```

```powershell
cd app
npm run web
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\auto-import-watch.ps1 -Watch -Provider local-fast -SpeakResult
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\demo-network-preflight.ps1
```

## Verification Standard

- For docs/config changes: parse JSON and PowerShell scripts.
- For app/server changes: run `npm test` from `app/`.
- For browser UI changes: run Playwright if dependencies are installed.
- For import pipeline changes: run `pipeline/disease-scout-automated-import/scripts/smoke-test-local-fast.ps1`.
- Record any untested hardware assumption as blocked, not complete.
