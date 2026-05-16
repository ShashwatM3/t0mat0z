# Demo Day Status: Disease Scout Memory

Generated: 2026-05-16T09:19:10.2796495-07:00
Status: warn

## Open First

1. Web simulator: `http://localhost:19006`
2. Operator card: `final_docs/overnight/demo-operator-card.md`
3. Proof packet: `final_docs/overnight/demo-day-proof-packet.md`
4. Demo ready JSON: `final_docs/overnight/demo-ready-check.json`
5. Morning audit after 10:00: `docs/goals/disease-scout-overnight-experiment-control/notes/morning-audit.md`
6. Dogbot Project Control: Discord `#dogbot`

## Live Services

- Web: ok=True, url=http://localhost:19006, length=1271
- Backend: ok=True, provider=codex-cli, model=gpt-5.5
- Heartbeat: status=running, pid=18916, stop_at=2026-05-16T10:00:00.0000000-07:00
- Morning audit: exists=False, path=docs/goals/disease-scout-overnight-experiment-control/notes/morning-audit.md

## Proof Summary

- Demo ready: status=warn, blockers=0, warnings=2
- Dogbot: receipts=49, flagged=0, pending=0, source=artifact
- Network: status=warn, route=tailscale, recommended_api=http://100.127.164.111:8787/api/scout/analyze
- Live model: status=pass, model=codex-cli:gpt-5.5:low, confidence=low, treatment=
- Diversity: status=pass, samples=3, unique_signatures=3, treatment_advice_count=0, failed_sample_count=0
- Live UI: status=pass, image=disease_scout_blind_09.jpg, model=codex-cli:gpt-5.5:low, screenshot=final_docs/overnight/live-ui-upload-smoke.png
- Visual audit: status=pass, verdict=demo_visuals_not_obviously_broken, screenshots=5, failed=0
- Latency audit: status=pass, max_model=14405 ms, average_model=12305 ms, fallback=If a live model call stalls during judging, show live-model-diversity-smoke.json, live-ui-upload-smoke.png, and demo-day-status.md first, then retry the live upload.
- Dogbot auth: status=pass, selected=DISCORD_BOT_TOKEN/User, blocker=
- Dogbot target guild visible: True

## Required Files

- Operator card: present - `final_docs/overnight/demo-operator-card.md`
- Proof packet: present - `final_docs/overnight/demo-day-proof-packet.md`
- Demo ready JSON: present - `final_docs/overnight/demo-ready-check.json`
- Morning audit: missing - `docs/goals/disease-scout-overnight-experiment-control/notes/morning-audit.md`
- Live UI screenshot: present - `final_docs/overnight/live-ui-upload-smoke.png`
- Display screenshot: present - `final_docs/overnight/baseline-display-600.png`
- Visual audit: present - `final_docs/overnight/visual-professionalism-audit.md`
- Latency audit: present - `final_docs/overnight/latency-demo-audit.md`
- Dogbot auth repair: present - `final_docs/overnight/dogbot-auth-repair.md`
- FieldBot invite launcher: present - `final_docs/overnight/open-fieldbot-hackathon-invite.cmd`
- Dogbot pending queue: missing - `final_docs/overnight/dogbot-pending-receipts.jsonl`
- DAT checklist: present - `final_docs/android-dat-checklist.md`

## Blockers

- none

## Warnings

- Network preflight has warnings: Only non-private-LAN candidates responded to /health. If this is a Tailscale address, the phone must also be on Tailscale; venue Wi-Fi still needs a separate check.
- Morning audit is pending until 10:00 AM.

## Demo Claim Boundary

- Say: hands-free evidence memory, conservative possible disease or stress, missing evidence, next check, supervisor packet.
- Do not say: final diagnosis, pesticide/treatment recommendation, completed native DAT app, venue Wi-Fi route proven.
