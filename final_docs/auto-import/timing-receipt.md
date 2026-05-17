# Automated Import Timing Receipt

Generated: 2026-05-16

## Result

Automated folder import is mechanically reliable once the image lands in the watched folder.

The speed decision is:

- Use `local-fast` for the wearer-facing live demo loop.
- Keep `live` model mode for proof receipts and richer classifier evidence.

## Measured Runs

| Mode | Image source | Result | Elapsed |
| --- | --- | --- | ---: |
| `live` | watched-folder tomato image | pass | 45455 ms |
| `local-fast` | watched-folder tomato image | pass | 188 ms |

Existing browser/live-model receipts:

| Receipt | Result |
| --- | --- |
| `final_docs/overnight/live-ui-upload-smoke.json` | pass, model latency 11115 ms |
| `final_docs/overnight/latency-demo-audit.md` | pass, max model latency 14405 ms, average 12305 ms |

## Demo Implication

For a live judge demo, `codex-cli` live mode is too slow as the primary wearer-facing loop. The best demo flow is:

1. Watcher detects imported image.
2. `local-fast` returns immediate triage and next check.
3. Phone/laptop speaks or notifies the wearer.
4. Dashboard shows saved JSON and supervisor packet.
5. Live-model proof receipts are available to show that richer image analysis also works.

This is honest if described as fast automated triage plus live-model evidence, not a final diagnosis engine.
