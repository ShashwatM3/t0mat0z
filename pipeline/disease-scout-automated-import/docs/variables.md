# Editable Variables

Main config: `config/pipeline.example.json`

## Pipeline

| Variable | Meaning |
| --- | --- |
| `pipeline.mode` | Default mode: `local-fast` or `live`. |
| `pipeline.watch` | Keep watching for new images. |
| `pipeline.speakResult` | Speak the one-line result through current audio output. |
| `pipeline.pollIntervalSeconds` | Watch loop interval. |
| `pipeline.targetResultSeconds` | Target time from detected image to result. |
| `pipeline.targetCaptureToWearerSeconds` | Target total time from capture/import to wearer result. |

## Paths

| Variable | Meaning |
| --- | --- |
| `paths.autoImportScript` | Canonical watcher script path from repo root. |
| `paths.watchPath` | Incoming image folder. |
| `paths.outDir` | Result JSON and summary output folder. |
| `paths.testSampleImage` | Image copied by the local smoke test. |

## Classifier

| Variable | Meaning |
| --- | --- |
| `classifier.apiUrl` | Current analyze endpoint. |
| `classifier.provider` | Wrapper default: `local-fast` or `live`. |
| `classifier.liveProvider` | Server provider: `codex-cli`, `openai`, `gemini`, or custom. |
| `classifier.customBridgeUrl` | Optional teammate bridge URL. |
| `classifier.timeoutSeconds` | Live request timeout. |

## Observation Defaults

| Variable | Meaning |
| --- | --- |
| `observationDefaults.workerId` | Worker/scout id for records. |
| `observationDefaults.crop` | Crop label. |
| `observationDefaults.zone` | Field/greenhouse/row zone. |
| `observationDefaults.wearerNote` | Default note when no voice/text context exists. |

## Wearer Return

| Variable | Meaning |
| --- | --- |
| `wearerReturn.channel` | `audio`, `notification`, or `display`. |
| `wearerReturn.audioEnabled` | Enable local speech output. |
| `wearerReturn.notificationEnabled` | Reserved for teammate phone notification bridge. |
| `wearerReturn.displayEnabled` | Only for MRBD/display hardware after testing. |
| `wearerReturn.maxSentenceCharacters` | Keep result short enough for audio. |
| `wearerReturn.template` | One-line wearer result template. |

## Environment Variables

Server/provider variables live in `config/local.env.example.ps1`.

Never commit real key values.
