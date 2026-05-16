# Disease Scout Memory Discord project state

Audience: Discord team update.
Privacy rule: visible Discord content must not include local machine paths, private account details, tokens, raw agent logs, or personal file details.
Formatting rule: use readable Discord markdown, with one idea per line and no threads.

## #general

**Current project state**
*Disease Scout Memory* is the current Sunday demo lane for the AIFS x Meta Wearables AgTech hackathon.

**Core loop**
Field worker sees a suspect plant.
Glasses-style POV capture records what the worker is seeing.
Worker adds a short spoken/text note.
System returns a conservative disease/stress assessment with uncertainty.
System asks for the next missing evidence view.
Supervisor receives a structured review packet.

**Team use**
Use the channel-specific posts as the current map.
No threads are needed.

## #start-here

**Start here**
*Disease Scout Memory* is not a generic “AI glasses identify plants” demo.

**Wearer action**
A field worker looks at a tomato plant station and gives a short report.

**Glasses input**
POV image/capture.
Wearer voice or text stand-in.
Session context from the phone/app.

**Structured output**
Possible disease or stress ID.
Confidence and evidence quality.
Limitations and missing views.
Next check.
Review status.
Supervisor action.
No treatment recommendation.

**Judge-visible proof**
Simulator UI.
Structured JSON packet.
Verifier report.
Pending-capture and completed-packet screenshots.

## #decisions

**Current decisions**
**1.** Sunday lane is *Disease Scout Memory*.
**2.** Demo focus is tomato disease scouting with supervisor review.
**3.** The system must name uncertainty instead of pretending certainty.
**4.** The system must request missing evidence before overclaiming.
**5.** Treatment advice stays out of scope for the demo.
**6.** The phone/app owns the session; glasses are the capture and wearer-audio surface.
**7.** Discord is a project status board, not a product dependency.

## #blockers

**Current blockers and risks**
Real glasses session behavior still needs device validation.
Broad state classification has known misses on healthy and poor-evidence cases.
Current screenshots show simulator proof, not full device capture.
The demo must not drift into agronomy treatment recommendations.
The final walkthrough needs a short manual acceptance pass before presentation.

**Not blocked on**
Public/private credentials are not needed in this server.
Personal machine details are not needed in this server.
Threads are not needed for the current update structure.

## #resources

**Useful reference areas**
Meta Wearables DAT documentation.
Android and iOS DAT sample repositories.
Expo / React Native web prototype references.
Hackathon agenda and judging context.
Internal verifier report and screenshot proof.

**DAT facts to keep honest**
Phone app starts and owns the session.
Glasses provide POV camera/photo/video, wearer mic, speakers, and session controls.
HFP microphone audio is wearer-voice oriented and low fidelity.
Assume one active glasses session per device.
Do not assume lens overlays unless verified on device/docs.
Do not assume Meta AI voice-command integration unless verified on device/docs.

## #use-cases

**Primary use case**
Field disease scouting memory.

**Why this is stronger than generic identification**
The worker closest to the issue captures evidence without stopping work.
The system turns that moment into a reviewable record.
The record is useful even when the model is uncertain.
The supervisor can inspect what was captured, what was inferred, and what is missing.

**Secondary lanes**
Harvest or packing QA.
Safety checklist capture.
Expert-in-the-loop triage.
These stay secondary unless the disease scouting lane breaks.

## #technical-notes

**Technical state**
Expo / React Native web simulator is active.
Local AI proxy accepts image data and scout context.
Main analysis route is `POST /api/scout/analyze`.
Health route is `GET /health`.
Default local analysis can use a Codex CLI bridge when no API key is set.
Optional cloud vision path is available through environment configuration.

**Structured output fields**
`possible_disease`
`confidence`
`evidence_quality`
`limitation_flags`
`next_check`
`review_status`
`supervisor_action`
`finding_why`
`broad_state`
`visible_symptoms`
`treatment_recommendation: null`

## #mobile-app

**Mobile/app state**
Simulator includes plant station selection.
Simulator includes glasses-view capture panel.
Simulator includes evidence upload and operator report.
Simulator includes scout conversation controls.
Simulator includes assessment panel.
Simulator includes supervisor packet view.
Simulator includes raw JSON proof.

**Current demo fixture**
Zone B suspicious lower-leaf tomato plant.
Worker notes yellowing and spots on lower leaves.
System returns possible early blight or leaf spot with medium confidence.
System explains why.
System asks for underside view and healthy comparison.
System creates a supervisor packet.

## #backend-ai

**Backend/AI verification state**
Manifest rows checked: **306**.
Prediction rows checked: **306**.
Missing predictions: **0**.
Extra predictions: **0**.

**Passing checks**
Valid schema: **306 / 306**.
Limitations named: **306 / 306**.
Next check exists: **306 / 306**.
No treatment advice: **306 / 306**.
Report preserved: **306 / 306**.
Safe review status: **306 / 306**.

**Known quality issues**
Broad state classification: **247 / 306**, **80.7%**.
Bad recapture behavior: **85 / 102**, **83.3%**.

## #demo-script

**Demo script**
**1.** Select Zone B: suspicious lower-leaf tomato plant.
**2.** Worker report: *yellowing and spots on lower leaves*.
**3.** Trigger capture.
**4.** Ask: *what disease might this be?*
**5.** Show possible early blight or leaf spot with medium confidence.
**6.** Ask: *why?*
**7.** Show missing evidence: underside view and healthy comparison.
**8.** Create supervisor packet.
**9.** Point judges to JSON proof and the no-treatment safety guard.

**Acceptance target**
Judges can see what the worker did, what the system captured, what the model inferred, what it refused to overclaim, and what the supervisor can inspect.

## #agent-log

**Agent receipt**
Discord project-state posts are managed bot posts.
Updates are rerunnable and should edit existing messages rather than spam new ones.
Visible content intentionally excludes local personal paths, tokens, account details, and raw logs.
Screenshots are attached only as demo proof.

**Repo organization note**
Project-facing docs live in final documentation areas.
Repeatable Discord update logic lives with scripts.
Discord message IDs live in a manifest so future runs update the same posts.

## #goals

**Next build goals**
**1.** Keep Sunday demo narrow and rehearse the Zone B flow end-to-end.
**2.** Fill the manual acceptance checklist for real glasses or mock-device capture.
**3.** Improve broad-state and bad-recapture verifier behavior.
**4.** Keep the supervisor packet legible enough for judges to inspect quickly.
**5.** Do not broaden into generic ag assistant scope.

**Definition of done**
A judge can follow the field action.
A judge can inspect the structured output.
A judge can see uncertainty and missing evidence.
A judge can verify that treatment advice was not generated.
