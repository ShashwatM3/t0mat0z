# Latency Demo Audit

Generated: 2026-05-16T09:17:23.3828309-07:00
Status: pass
Max model latency: 14405 ms
Average model latency: 12305 ms
Max service latency: 95 ms

## Model Latencies

- live_model_smoke: 14006 ms from live-model-smoke.json
- live_ui_upload: 11115 ms from live-ui-upload-smoke.json
- diversity_diversity-spot-01: 14405 ms from live-model-diversity-smoke.json
- diversity_diversity-healthy-01: 9829 ms from live-model-diversity-smoke.json
- diversity_diversity-curl-01: 12171 ms from live-model-diversity-smoke.json

## Service Latencies

- web_status: 95 ms from http://localhost:19006
- backend_health: 5 ms from http://localhost:8787/health

## Demo Fallback

If a live model call stalls during judging, show live-model-diversity-smoke.json, live-ui-upload-smoke.png, and demo-day-status.md first, then retry the live upload.

## Blockers

- none

## Warnings

- none
