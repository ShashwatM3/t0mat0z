# Disease Scout Memory project state

Audience: Discord team update.
Privacy rule: do not include local machine paths, private account details, tokens, or raw agent logs in Discord.

## Current wedge

Disease Scout Memory: Meta glasses help a field worker capture plant disease evidence hands-free, get a conservative possible disease/stress ID with uncertainty, collect the next missing disease-specific view, and create a supervisor-ready disease packet plus zone watch record.

## Demo proof

The current web/Expo simulator demonstrates:

1. Plant station selection: healthy baseline, suspicious lower-leaf plant, ambiguous poor-evidence plant.
2. DAT-like glasses capture stand-in: wearer POV evidence record plus operator report.
3. Conservative disease assessment: possible ID, confidence, limitations, next check, and no treatment recommendation.
4. Supervisor packet: structured observation JSON and visible packet card.
5. Screenshot proof: pending-capture and completed-packet screenshots under `final_docs/screenshots/`.

## Technical state

- App: Expo / React Native web simulator.
- UI entry: `app/App.js`.
- Local AI proxy: `app/server.mjs`.
- Proxy endpoint: `POST /api/scout/analyze`.
- Health endpoint: `GET /health`.
- Default model path: local Codex CLI bridge when no OpenAI API key is set; OpenAI Responses vision path is optional via environment.
- Structured output: `DiseaseScoutObservation` style object with confidence, limitation flags, next check, review status, visible symptoms, model metadata, and `treatment_recommendation: null`.

## Verification state

Dataset verifier report currently covers 306 rows.

Passing checks:

- Valid schema: 306 / 306.
- Limitations named: 306 / 306.
- Next check exists: 306 / 306.
- No treatment advice: 306 / 306.
- Report preserved: 306 / 306.
- Safe review status: 306 / 306.

Open quality issue:

- Broad state classification is not fully reliable yet: 247 / 306, 80.7%.
- Bad recapture behavior is good but not perfect: 85 / 102, 83.3%.

## DAT constraints to keep honest

- Phone app owns the session; glasses are not standalone compute.
- Useful DAT primitives are POV camera/video/photo, wearer mic, wearer speakers, and session controls.
- HFP microphone audio is wearer-voice oriented and low fidelity, so do not design around ambient audio classification.
- Only one active glasses session per device.
- Do not claim lens overlays or Meta AI voice commands unless current device/docs prove them.

## Next build slice

1. Keep the Sunday demo narrow: Zone B suspicious tomato plant -> capture -> possible early blight/leaf spot -> ask why -> supervisor review packet.
2. Add a manual acceptance checklist for real glasses or mock-device run.
3. Improve verifier broad-state behavior on healthy and bad-recapture cases.
4. Keep Discord updated with managed bot posts, no threads, no local personal paths.
