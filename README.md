# lorem_ipsum

Monorepo-style layout with two top-level areas:

## [`app/`](./app/)

Expo + React Native disease scout simulator. All JavaScript, Expo config, assets, and Node dependencies live here. Install and run commands (`npm install`, `npm start`, `npm run web`, etc.) are executed **from inside `app/`**.

Current demo path: camera trigger -> disease question -> why question -> `DiseaseScoutObservation` JSON -> supervisor packet.

## [`glasses/`](./glasses/)

Placeholder folder for **glasses-related** work (content TBD). Add specs, prototypes, or a separate package here as the project grows.

## [`opportunities/`](./opportunities/)

Opportunity-specific work lanes for the Meta Wearables hackathon. Start each concept in its own folder so research, fixtures, acceptance checks, and prototypes do not get mixed together before a slice becomes shared app code.

## Security guard

This repo blocks local agent/operator config, environment files, signing keys, local databases, and obvious token patterns. After cloning, enable the shared hooks once:

```powershell
git config core.hooksPath .githooks
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-sensitive-files.ps1 -Mode Current
```
