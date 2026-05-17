# Acceptance Checklist

## Import

- [ ] A new image can appear in the configured `watchPath`.
- [ ] The watcher detects the newest image without manual file selection.
- [ ] The watcher ignores non-image files.
- [ ] Output JSON and summary text are written.

## Classifier

- [ ] `local-fast` returns in under 1 second for the demo image.
- [ ] `live` bridge returns a valid `DiseaseScoutObservation` when the API/server is available.
- [ ] Custom bridge returns the documented response shape.
- [ ] No output recommends treatment or claims final diagnosis.

## Wearer Return

- [ ] One-line result is short enough for audio.
- [ ] Audio, notification, or display path is selected.
- [ ] Ordinary Ray-Ban Meta path does not claim lens display.
- [ ] MRBD display path is marked blocked unless tested on MRBD.

## Supervisor Proof

- [ ] Full JSON is saved.
- [ ] Supervisor action exists.
- [ ] Next check exists.
- [ ] Evidence quality is visible.
- [ ] Timing receipt is saved.

## Demo Claim

- [ ] Fully automated claim is only used if no file picker is in the loop.
- [ ] Meta AI app is described as transport only, not classifier.
- [ ] DAT claims are only made if the DAT path is tested.
