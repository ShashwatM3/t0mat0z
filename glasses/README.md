# Glasses Integration Notes

This folder tracks the Meta Wearables Device Access Toolkit handoff for Disease Scout Memory.

Current status: checklist/scaffold only. Do not claim the repo contains a finished native DAT app.

## Thin Integration Target

Android DAT or MockDeviceKit should feed the existing app/server contract:

```text
Meta glasses / mock device photo
-> Android app session/capture handler
-> Disease Scout payload
-> local queue if offline
-> POST /api/scout/analyze when available
-> DiseaseScoutObservation
```

For web/phone rehearsal, do not rely on device-local `localhost`. The simulator uses
`EXPO_PUBLIC_DISEASE_SCOUT_API_URL` when provided, otherwise it infers the Expo page host and sends
analysis requests to port `8787` on that same host. On demo Wi-Fi, point phones to the laptop LAN
address and keep the AI proxy running on the laptop.
Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\demo-network-preflight.ps1`
from `prototype\t0mat0z` to write the current web/backend/listener/LAN proof packet before a
phone or glasses rehearsal.

## What To Build First

- Device or MockDeviceKit registration screen.
- Camera permission request.
- One-session start/stop controls.
- Low/medium camera stream.
- Single photo/frame capture.
- Payload handoff matching `final_docs/android-dat-checklist.md`.

## What Not To Claim Yet

- Standalone glasses compute.
- Lens overlay UI.
- Meta AI voice command trigger.
- Production field reliability.
- Autonomous disease diagnosis.
