# Disease Scout Classifier Prototype

Prototype repo for the Meta Wearables disease-scouting classifier demo. The repo is intentionally scoped to one path:

```text
plant image capture/import -> classifier triage -> DiseaseScoutObservation -> wearer result + supervisor packet
```

## [`app/`](./app/)

Expo + React Native disease scout simulator. All JavaScript, Expo config, assets, and Node dependencies live here. Install and run commands (`npm install`, `npm start`, `npm run web`, etc.) are executed **from inside `app/`**.

Current demo path: camera trigger -> disease question -> why question -> `DiseaseScoutObservation` JSON -> supervisor packet.

## [`pipeline/disease-scout-automated-import/`](./pipeline/disease-scout-automated-import/)

Teammate handoff package for the current automated import pipeline: capture/import source, watched-folder or DAT bridge, classifier request/response contract, editable variables, wearer-facing return path, timing receipts, and agent instructions for porting into another process.

## [`glasses/`](./glasses/)

Meta DAT handoff notes for the Disease Scout capture path. This is currently a checklist/scaffold, not a finished native Android app. The exact real-device acceptance checklist lives at [`final_docs/android-dat-checklist.md`](./final_docs/android-dat-checklist.md).

## [`final_docs/`](./final_docs/)

Reference docs, real-device caveats, and demo receipts. The active classifier proof receipts are in [`final_docs/overnight/`](./final_docs/overnight/) and [`final_docs/auto-import/`](./final_docs/auto-import/).

## Security guard

This repo blocks local agent/operator config, environment files, signing keys, local databases, and obvious token patterns. After cloning, enable the shared hooks once:

```powershell
git config core.hooksPath .githooks
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-sensitive-files.ps1 -Mode Current
```
