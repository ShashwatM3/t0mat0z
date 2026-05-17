# Architecture

## Pipeline

```text
capture source
  -> import surface
  -> automated ingest
  -> classifier bridge
  -> observation normalizer
  -> wearer return
  -> supervisor packet / dashboard proof
```

## Capture Sources

| Source | Status | Notes |
| --- | --- | --- |
| DAT `capturePhoto` | Best final path | True app-controlled image bytes, but depends on DAT integration working. |
| Meta AI app import + Android gallery watcher | Best fallback | Watch new gallery media and POST to classifier. |
| Meta AI app import + sync folder | Practical fallback | Watch a synced folder on laptop. Import latency varies. |
| Browser file picker | Semi-automated only | Useful for testing, not a fully automated claim. |

## Classifier Modes

| Mode | Use | Truthful claim |
| --- | --- | --- |
| `local-fast` | Live wearer feedback | Fast triage baseline, not final model. |
| `live` with `codex-cli` | Proof/richer analysis | Real LLM vision bridge, slower. |
| `live` with OpenAI/Gemini | Faster richer analysis if key exists | Swappable classifier bridge. |
| custom bridge | Teammate process | Must match request/response contract. |

## Return-to-Wearer

Ordinary Ray-Ban Meta:

- audio through paired glasses;
- phone notification/message announced or read by glasses.

Meta Ray-Ban Display:

- display/Web App result only if tested on MRBD hardware.

The worker-facing result should be one sentence. The supervisor packet can be detailed.
