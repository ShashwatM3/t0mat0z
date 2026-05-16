# Demo Day Proof Packet: Disease Scout Memory

Use this as the judge-facing proof route after the 10:00 AM audit completes.

## One-Line Claim

Disease Scout Memory turns a field worker's hands-free plant observation into a structured disease-evidence packet: possible disease or stress, uncertainty, missing evidence, next check, and supervisor review state.

## Demo Flow

1. Show the real plant or produce station.
2. Worker says or types a short observation such as: "yellowing and spots on lower leaves."
3. Worker uploads/captures a leaf image in the simulator.
4. System returns a conservative `DiseaseScoutObservation`.
5. Show the supervisor packet and JSON record.
6. Pull up the deferred-processing panel and explain what happens if connectivity fails.
7. Open Dogbot `#dogbot` to show verified experiment receipts and reactions if live access is working. If not, show the current `dogbot-auth-status.json` blocker and the queued receipt file instead of pretending Discord is live.
8. Open the Android/DAT checklist to show exactly what must pass on real glasses.

## Open These Artifacts

- `prototype/t0mat0z/app/`
- `prototype/t0mat0z/final_docs/overnight/demo-operator-card.md`
- `prototype/t0mat0z/final_docs/overnight/demo-day-status.md`
- `prototype/t0mat0z/final_docs/overnight/baseline-desktop.png`
- `prototype/t0mat0z/final_docs/overnight/baseline-mobile-390.png`
- `prototype/t0mat0z/final_docs/overnight/baseline-display-600.png`
- `prototype/t0mat0z/final_docs/overnight/visible-holdout-score-latest.md`
- `prototype/t0mat0z/final_docs/overnight/live-model-smoke.json`
- `prototype/t0mat0z/final_docs/overnight/live-model-diversity-smoke.json`
- `prototype/t0mat0z/final_docs/overnight/live-ui-upload-smoke.json`
- `prototype/t0mat0z/final_docs/overnight/live-ui-upload-smoke.png`
- `prototype/t0mat0z/final_docs/overnight/visual-professionalism-audit.md`
- `prototype/t0mat0z/final_docs/overnight/visual-professionalism-audit.json`
- `prototype/t0mat0z/final_docs/overnight/latency-demo-audit.md`
- `prototype/t0mat0z/final_docs/overnight/latency-demo-audit.json`
- `prototype/t0mat0z/final_docs/overnight/demo-ready-check.json`
- `prototype/t0mat0z/final_docs/overnight/dogbot-auth-status.json`
- `prototype/t0mat0z/final_docs/overnight/dogbot-pending-receipts.jsonl`
- `prototype/t0mat0z/final_docs/overnight/open-fieldbot-hackathon-invite.cmd`
- `prototype/t0mat0z/final_docs/android-dat-checklist.md`
- `docs/goals/disease-scout-overnight-experiment-control/notes/morning-audit.md`
- Discord `#dogbot` receipt manifest: `prototype/t0mat0z/final_docs/discord-experiment-manifest.json`

## Allowed Claims

- The web simulator implements the evidence-memory workflow.
- Upload/model analysis uses a server-side provider boundary.
- The provider path can switch among `codex-cli`, `openai`, and `gemini` without browser changes.
- One live uploaded holdout image reached `/api/scout/analyze` through `codex-cli:gpt-5.5:low` with the original label omitted from the request.
- Three blinded live uploaded holdout images produced distinct structured observations, proving the bridge is not returning a static response for every image.
- The browser UI itself uploaded a blind image, preserved the typed worker report, reached the live backend, and displayed a conservative supervisor-review packet.
- A phone-opened simulator can target the laptop backend through `EXPO_PUBLIC_DISEASE_SCOUT_API_URL` or same-host LAN inference instead of device-local `localhost`.
- Failed uploaded analysis is queued locally instead of generating fake assessments.
- Browser tests verify desktop, mobile, and 600x600 display-style layouts.
- Visual audit verifies the screenshot artifacts are fresh, sized to the intended viewports, and not blank or visually collapsed.
- Latency audit records live model/service timings and names the fallback proof path if live model calls stall.
- Dataset verification is honest: it preserves failures and separately reports safety/schema checks.
- Dogbot receipts are technical-only and include thumbs-up/down reactions for morning review.
- If Dogbot live access is blocked, queued local receipts remain local until access is repaired and live audit passes.
- Android/DAT work is an integration checklist and payload contract unless real-device rows are filled.

## Do Not Claim

- Do not claim a completed native Android DAT app.
- Do not claim lens overlays, Meta AI voice-command integration, or standalone glasses compute.
- Do not claim final disease diagnosis.
- Do not recommend pesticide or treatment actions.
- Do not hide the holdout verifier failures.
- Do not imply that one leaf image is enough for production field pathology.

## Live Verification Commands

Run from `prototype/t0mat0z/app`:

```powershell
npm test
$env:DISEASE_SCOUT_WEB_URL = "http://localhost:19006"
npx playwright test
```

Run from `prototype/t0mat0z`:

```powershell
python scripts\dogbot-experiment-log.py audit
python scripts\dogbot-experiment-log.py flush-pending
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\disease-verifier.ps1 -Command Score -Manifest .\data\verifier\manifests\holdout_captures.jsonl -Predictions .\data\verifier\predictions\holdout.jsonl -Out .\final_docs\overnight\visible-holdout-score-latest.md
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-sensitive-files.ps1 -Mode Current
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\visual-professionalism-audit.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\latency-demo-audit.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\demo-ready-check.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\demo-day-status.ps1
```

## Live Model Proof

- `final_docs/overnight/live-model-smoke.json` proves one real uploaded PlantDoc holdout image reached `POST /api/scout/analyze`.
- `final_docs/overnight/live-model-diversity-smoke.json` proves the live model bridge gives non-static structured responses across blinded holdout images.
- `final_docs/overnight/live-ui-upload-smoke.json` proves the actual browser upload flow reached the same backend and rendered the result.
- `final_docs/overnight/live-ui-upload-smoke.png` shows the UI state after the browser upload and model result.
- The request used a neutral upload filename and omitted the original dataset label from the request body.
- The live provider was `codex-cli` with `gpt-5.5` low reasoning effort.
- The response stayed in the Disease Scout lane: conservative possible disease or stress, low confidence, limitation flags, next check, supervisor review, and no treatment recommendation.

Run from repo root:

```powershell
node "$env:USERPROFILE\.codex\skills\goalbuddy\scripts\check-goal-state.mjs" docs\goals\disease-scout-overnight-experiment-control\state.yaml
```

## If Glasses Work Tomorrow

Fill the Android/DAT checklist rows in order:

1. Device visible for development.
2. Camera permission allowed.
3. One active session starts.
4. A plant image/frame is captured.
5. The captured image maps to the same payload contract.
6. Backend `/health` is reachable from the phone or DAT app using the laptop LAN route.
7. Online analysis returns `DiseaseScoutObservation`.
8. Offline failure queues the capture as `needs_connectivity`.
9. Session stops cleanly.

## If Glasses Fail Tomorrow

Use the fallback script:

"The real-glasses integration path is camera/photo/session capture into the same evidence packet contract. Today this station demonstrates the verified packet workflow, deferred capture behavior, verifier results, and the exact Android/DAT acceptance checks needed to prove the hardware handoff."

## If Dogbot Is Blocked Tomorrow

Use the fallback script:

"The Discord control-channel proof is deliberately not being faked. The last-good Dogbot manifest is preserved, the current auth blocker is visible in `dogbot-auth-status.json`, and successful local checks are queued in `dogbot-pending-receipts.jsonl` until the bot can read and post in Project Control again."

Repair path if someone has server permission: open `open-fieldbot-hackathon-invite.cmd`, approve FieldBot in the hackathon server, then run `scripts/repair-dogbot-auth.ps1 -SkipTokenPrompt` from `prototype/t0mat0z`.
