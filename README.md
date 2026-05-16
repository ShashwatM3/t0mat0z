# lorem_ipsum

Monorepo-style layout with two top-level areas:

## [`app/`](./app/)

Expo + React Native disease scout simulator. All JavaScript, Expo config, assets, and Node dependencies live here. Install and run commands (`npm install`, `npm start`, `npm run web`, etc.) are executed **from inside `app/`**.

Current demo path: camera trigger -> disease question -> why question -> `DiseaseScoutObservation` JSON -> supervisor packet.

## [`glasses/`](./glasses/)

Meta DAT handoff notes for the Disease Scout capture path. This is currently a checklist/scaffold, not a finished native Android app. The exact real-device acceptance checklist lives at [`final_docs/android-dat-checklist.md`](./final_docs/android-dat-checklist.md).

## [`opportunities/`](./opportunities/)

Opportunity-specific work lanes for the Meta Wearables hackathon. Start each concept in its own folder so research, fixtures, acceptance checks, and prototypes do not get mixed together before a slice becomes shared app code.

## Security guard

This repo blocks local agent/operator config, environment files, signing keys, local databases, and obvious token patterns. After cloning, enable the shared hooks once:

```powershell
git config core.hooksPath .githooks
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-sensitive-files.ps1 -Mode Current
```
