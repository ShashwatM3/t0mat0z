# Demo Runbook

## Fast Demo

1. Start the local AI proxy only if you also want live model proof:

```powershell
cd app
npm run ai-server
```

2. Start the automated import watcher in fast mode:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\pipeline\disease-scout-automated-import\scripts\run-auto-import-watch.ps1 -Watch -Provider local-fast -SpeakResult
```

3. Put a disease image into the configured incoming folder.

4. Watch for:

- result JSON in the output folder;
- summary text;
- spoken result if audio is enabled.

5. Open the web simulator or proof packet for supervisor view.

## Live Model Proof

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\pipeline\disease-scout-automated-import\scripts\run-auto-import-watch.ps1 -Watch -Provider live
```

Use live mode when latency is acceptable or when proving the LLM bridge.

## Expected Timing

- `local-fast`: under 1 second after image detection.
- `live` with current `codex-cli`: measured 11-45 seconds.

## Fallback Script

If the live model stalls:

1. Keep the fast watcher running.
2. Show `final_docs/overnight/live-ui-upload-smoke.json`.
3. Show `final_docs/overnight/latency-demo-audit.md`.
4. Explain that live LLM proof exists, while the wearer-facing loop uses fast triage for demo reliability.
