# Demo Operator Card: Disease Scout Memory

Use this at the table before judges arrive. It is the shortest path from cold status to a credible demo.

## Open First

1. Web simulator: `http://localhost:19006`
2. Demo day status: `prototype/t0mat0z/final_docs/overnight/demo-day-status.md`
3. Dogbot Project Control: Discord `#dogbot` if live access is working
4. Morning audit after 10:00: `docs/goals/disease-scout-overnight-experiment-control/notes/morning-audit.md`
5. Proof packet: `prototype/t0mat0z/final_docs/overnight/demo-day-proof-packet.md`
6. DAT checklist: `prototype/t0mat0z/final_docs/android-dat-checklist.md`
7. Demo readiness: `prototype/t0mat0z/final_docs/overnight/demo-ready-check.json`
8. Visual audit: `prototype/t0mat0z/final_docs/overnight/visual-professionalism-audit.md`
9. Latency audit: `prototype/t0mat0z/final_docs/overnight/latency-demo-audit.md`
10. Dogbot auth status: `prototype/t0mat0z/final_docs/overnight/dogbot-auth-status.json`
11. Dogbot repair launcher: `prototype/t0mat0z/final_docs/overnight/open-fieldbot-hackathon-invite.cmd`

## Current Live Services

- Web: `http://localhost:19006`
- Backend health: `http://localhost:8787/health`
- Analyze endpoint: `http://localhost:8787/api/scout/analyze`
- Current non-local route: see `final_docs/overnight/network-preflight-latest.json`
- Current caveat: if the route type is `tailscale`, it is not proof that a phone on venue Wi-Fi can reach the laptop.

## Two-Minute Demo

1. Put a real plant, tomato leaf, or produce sample in front of the laptop/glasses station.
2. In the simulator, upload one blind test image from `%USERPROFILE%\Downloads\DiseaseScout-Test-Images-20260516-000304\blind_upload_images`.
3. Type: `tomato leaf observation`
4. Press `Trigger capture`.
5. Press `Ask identify disease`.
6. Press `Ask why`.
7. Press `Create supervisor packet`.
8. Point to the assessment, next check, supervisor packet, verifier, and JSON.
9. If Dogbot live access is working, open `#dogbot` and show the latest receipts plus reactions. If it is blocked, show `demo-day-status.md`, `dogbot-auth-status.json`, and `dogbot-pending-receipts.jsonl` and say the Discord control surface is blocked, not faked.

## Say This

"The glasses value is not magic disease diagnosis. The value is hands-free evidence memory: image, worker note, uncertainty, missing evidence, next check, and a supervisor packet that can be reviewed later."

"The model is intentionally conservative. It asks for underside views and healthy comparisons instead of pretending one image is enough."

"If connectivity fails, the capture is queued locally rather than faking an answer."

## Proof To Show

- `live-model-diversity-smoke.json`: three blinded uploads, non-static structured outputs.
- `live-model-smoke.json`: one live uploaded holdout image through `/api/scout/analyze`.
- `live-ui-upload-smoke.json` and `live-ui-upload-smoke.png`: real browser upload flow with typed report, live model response, and supervisor packet.
- `visual-professionalism-audit.md`: screenshot freshness, viewport sizing, and nonblank visual proof for the demo interface.
- `latency-demo-audit.md`: live model/service timing plus the fallback path if the model is slow at the table.
- `demo-ready-check.json`: compact status of live services, proof files, Dogbot manifest, and known warnings.
- `demo-day-status.md`: one-page operator status assembled from the current proof files.
- `visible-holdout-score-latest.md`: dataset verifier with failures visible.
- `network-preflight-latest.json`: web/backend/listener route status and phone-route caveat.
- `discord-experiment-manifest.json`: Dogbot receipt ids and screenshot cadence.
- `dogbot-auth-status.json`: current live Discord access check.
- `dogbot-pending-receipts.jsonl`: local receipts waiting to flush if Dogbot access is restored.

## Do Not Say

- Do not claim completed native DAT integration unless the checklist rows are filled with real device evidence.
- Do not claim final disease diagnosis.
- Do not recommend treatment or pesticide actions.
- Do not hide verifier failures.
- Do not claim venue Wi-Fi phone routing works until `/health` is verified from that device.

## If The Model Is Slow

Use an already generated proof file first, then come back to the live upload. The strongest backup is `live-model-diversity-smoke.json` plus the screenshots.

## If Dogbot Is Blocked

"The control-channel integration is intentionally gated. We are showing the stale last-good manifest separately from the current live auth blocker, and local receipts are queued until the bot can read and post in Project Control again."

If the team has Discord server permission, run `prototype/t0mat0z/final_docs/overnight/open-fieldbot-hackathon-invite.cmd`, approve the bot in the hackathon server, then run `prototype/t0mat0z/scripts/repair-dogbot-auth.ps1 -SkipTokenPrompt`.

## If The Glasses Fail

"The real-glasses layer is the capture/input surface. The verified workflow is the evidence packet: POV image, wearer note, conservative assessment, missing evidence, next check, and supervisor review."
