# Android / Meta DAT Acceptance Checklist

Purpose: make the real-glasses test tomorrow concrete. This is not a claim that DAT integration is complete; it is the checklist for proving the handoff from Meta glasses capture into the Disease Scout workflow.

## Honest Current State

- Current app: Expo / React Native web simulator.
- Current glasses folder: checklist and handoff notes only.
- Real DAT Android app: not implemented in this repo yet.
- Valid claim today: the simulator proves the Disease Scout observation workflow.
- Valid claim after this checklist passes: a DAT/MockDevice capture can provide the evidence input for that workflow.

## DAT Facts To Preserve

- Phone app owns registration, permissions, and active session.
- Glasses supply wearer POV camera/video/photo, wearer-oriented HFP mic, speakers, and session controls.
- Camera permission is mediated through the Meta AI app.
- Microphone permission is platform Bluetooth/HFP permission.
- Assume one active glasses session per device.
- Do not claim lens overlays or Meta AI voice command integration unless tested.

## Minimal Android Slice

The Android slice should only prove:

1. Register/connect a device or MockDeviceKit device.
2. Request camera permission.
3. Start one active session.
4. Start camera stream at low or medium quality.
5. Capture one photo/frame.
6. Convert photo/frame to the same image payload shape used by the web simulator.
7. Attach wearer note text or voice-transcribed stand-in.
8. POST to `POST /api/scout/analyze` or queue locally if offline.
9. Render or log the returned `DiseaseScoutObservation`.
10. Stop/pause session cleanly.

Backend routing note for demo day: a phone or DAT app cannot call the laptop backend through its own
`localhost`. Use the laptop LAN address or an explicit `EXPO_PUBLIC_DISEASE_SCOUT_API_URL`, and
verify `/health` from the device network before claiming online analysis works.
Use `scripts/demo-network-preflight.ps1` before a rehearsal to record local backend/web health,
listeners, LAN candidates, and whether the best route is private LAN, Tailscale, or localhost-only.

## Payload Contract

The Android capture handoff should match the web server payload:

```json
{
  "observation_id": "android-zone-b-001",
  "worker_id": "worker-07",
  "crop": "tomato",
  "zone": "Zone B",
  "capture_source": "meta_dat_android_photo",
  "upload_filename": "dat-capture.jpg",
  "upload_size_bytes": 123456,
  "upload_mime_type": "image/jpeg",
  "report_channel": "wearer_voice_or_typed_stand_in",
  "wearer_note": "yellowing and spots on lower leaves",
  "image_data_url": "data:image/jpeg;base64,..."
}
```

## Manual Acceptance Table

| Check | Device / Mode | Input | Expected | Actual | Pass |
| --- | --- | --- | --- | --- | --- |
| Developer mode enabled | Real glasses | Meta AI app v254+ and supported firmware | Device visible for development | | |
| Mock device available | MockDeviceKit | Mock camera feed | App can start a mock session | | |
| Camera permission | Real or mock | Request camera | Permission status is allowed or explicit blocker is recorded | | |
| Session start | Real or mock | Start one session | Session state reaches started/streaming | | |
| Capture | Real or mock | Capture plant station | JPEG or frame bytes available to app | | |
| Offline queue | App/backend unavailable | Capture + note | Record persists as queued/needs_connectivity | | |
| Online analysis | Backend reachable | Capture + note | `DiseaseScoutObservation` returned | | |
| Safety posture | Any model response | Disease-like image | Uncertainty, limitations, next check, no treatment advice | | |
| Session stop | Real or mock | Stop/pause | Session ends without stuck camera | | |

## Demo Fallback If Hardware Fails

- Use web simulator with real plant/produce station.
- Show the Android/DAT checklist as honest hardware-readiness proof.
- Use screenshots and JSON verifier output as judge-visible artifacts.
- State clearly: "The glasses integration path is camera/photo/session capture into the same packet contract; today this station demonstrates the packet workflow."
