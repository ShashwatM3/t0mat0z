# Auto Research Improvements - Disease Scout

Generated: 2026-05-16 09:25 PT

## Current Read

Status: `warn`, not `complete`.

This improved materially overnight. It moved from a mostly static web demo into a verifiable field-evidence workflow with live image upload, a model bridge, offline/deferred capture behavior, visual checks, holdout scoring, Discord receipts, and a demo-day proof packet.

The work should not be called done yet because the controller was stopped before the 10:00 morning audit and the venue/private-LAN phone route is not proven. Dogbot project-control posting is now verified.

## Before -> After

| Before | After |
| --- | --- |
| Upload view looked like it returned similar/static answers. | Live UI upload smoke exists and uses `codex-cli:gpt-5.5:low`; diversity smoke found 3 unique response signatures across 3 samples. |
| Web simulator was the main artifact. | Web simulator now has backend model bridge, provider abstraction, mobile/display screenshots, and proof packet outputs. |
| No clean Gemini/OpenAI swap path. | Backend health reports supported providers: `codex-cli`, `openai`, `gemini`; Gemini key can be swapped in without changing the UI flow. |
| Offline capture was just an idea. | Deferred queue/retry behavior was added so capture can be stored and processed when the backend is reachable. |
| No strong verifier surface. | Holdout verifier ran 306 rows with failures visible, not hidden. Schema/safety checks pass at 100%; broad-state accuracy still needs work. |
| Dogbot posting was not visibly proven. | 51 receipts in `#dogbot`, under Project Control, 0 pending, 0 flagged; auth recovery posted a live restoration receipt. |
| Visual quality was subjective. | Visual professionalism audit passed with 5 screenshots and 0 failed checks. |
| Demo proof was scattered. | Operator card, proof packet, demo-day status, ready check, screenshots, latency audit, and network preflight now exist in `final_docs/overnight/`. |

## What Actually Improved

### 1. Disease Scout became a proof workflow

The demo is no longer "AI looks at leaf and diagnoses it." The current workflow is:

1. Worker captures leaf evidence.
2. Worker adds a typed report as a voice stand-in.
3. Backend returns a bounded scout assessment.
4. Output includes confidence, evidence quality, limitations, next check, and review status.
5. Supervisor/judges can inspect JSON, screenshots, receipts, and holdout failures.

This is closer to the competition wedge because the glasses value is hands-free evidence capture and structured memory, not pretending the camera is a perfect agronomist.

### 2. The model bridge is now real enough for testing

Receipts:

- Backend health: `http://localhost:8787/health`
- Active provider: `codex-cli`
- Active model: `gpt-5.5`
- Reasoning effort: `low`
- Supported providers: `codex-cli`, `openai`, `gemini`
- Live UI smoke: `final_docs/overnight/live-ui-upload-smoke.json`
- Live UI screenshot: `final_docs/overnight/live-ui-upload-smoke.png`

Important boundary: this is still not a committed API key setup. It is a local bridge for testing and can be swapped to Gemini or OpenAI later.

### 3. The verifier is harder to fake

The holdout verifier has 306 manifest rows and 306 predictions. It preserves failures instead of hiding them.

Latest visible scores:

| Check | Rate |
| --- | ---: |
| valid_schema | 100.0% |
| limitations_named | 100.0% |
| next_check_exists | 100.0% |
| no_treatment_advice | 100.0% |
| report_preserved | 100.0% |
| safe_review_status | 100.0% |
| broad_state | 80.7% |
| bad_recapture_behavior | 83.3% |

This means the system is behaving safely and structurally, but it is not yet accurate enough to overclaim plant health classification.

### 4. The demo surface got more professional

Receipts:

- Visual audit status: `pass`
- Verdict: `demo_visuals_not_obviously_broken`
- Screenshots checked: 5
- Failed visual checks: 0
- Baseline screenshots:
  - `final_docs/overnight/baseline-desktop.png`
  - `final_docs/overnight/baseline-mobile-390.png`
  - `final_docs/overnight/baseline-display-600.png`

The main improvement is that judges can now see a clean evidence-recording dashboard rather than only hearing a concept.

### 5. Dogbot project-control logging was repaired and proven

Receipts:

- Manifest messages: 51
- Screenshot-backed receipts: 17
- Pending receipts: 0
- Flagged receipts: 0
- Channel: `#dogbot`
- Category check: under Project Control = true
- Latest verified message: `T999-visible-20260516-091619`
- Recovery receipt: `T999-dogbot-auth-restored-20260516-091621`

This was a real improvement because the earlier loop had local receipts but the live Discord channel was not visibly receiving them.

### 6. Demo-day risk is now explicit

Current status is `warn` with 0 blockers and 2 warnings:

1. Network preflight only proved the non-private/Tailscale-style route. The phone route still needs a real venue Wi-Fi check.
2. Morning audit was pending until 10:00 AM but the controller was stopped manually, so that audit did not run.

## Competition Value

The winning story is now:

> Disease Scout is field evidence memory for plant disease scouting. The glasses capture what the worker actually saw, the system asks for missing evidence instead of pretending certainty, and the supervisor gets a reviewable packet with image, note, uncertainty, next check, and audit trail.

That is stronger than a generic "AI plant disease identifier" because it gives judges visible proof of:

- wearer action
- glasses-shaped input
- structured output
- uncertainty handling
- review workflow
- non-cheating verifier
- demo receipts

## What Did Not Improve Enough

- No real Meta DAT device session has been proven yet.
- No physical camera button trigger has been proven.
- No venue Wi-Fi phone path has been proven.
- No final morning audit exists because the controller was stopped.
- Broad plant health/disease classification still has visible holdout failures.
- This should not claim treatment advice or field-grade diagnosis.

## Important Files

- `final_docs/overnight/demo-day-status.md`
- `final_docs/overnight/demo-ready-check.json`
- `final_docs/overnight/demo-day-proof-packet.md`
- `final_docs/overnight/demo-operator-card.md`
- `final_docs/overnight/live-ui-upload-smoke.json`
- `final_docs/overnight/live-ui-upload-smoke.png`
- `final_docs/overnight/visible-holdout-score-latest.md`
- `final_docs/overnight/visual-professionalism-audit.md`
- `final_docs/overnight/latency-demo-audit.md`
- `final_docs/discord-experiment-manifest.json`
- `final_docs/overnight/dogbot-reaction-audit.json`
