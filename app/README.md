# Disease Scout Simulator

Expo + React Native simulator for the hackathon disease scouting demo.

The demo flow is intentionally narrow:

1. Worker sees a real plant station and triggers capture from the glasses.
2. Worker asks what disease or stress might be visible.
3. Worker asks why.
4. The app creates a concise `DiseaseScoutObservation` and supervisor review packet.

This proves the workflow without pretending the glasses can deliver high-confidence field pathology from one image. The win condition is the evidence trail, missing-evidence prompt, and supervisor packet.

From the repository root, enter this folder before installing or starting Expo:

```powershell
cd app
```

## Prerequisites

- **Node.js** (LTS recommended) and npm
- Optional: **Expo Go** on a phone for mobile preview

## Setup

```powershell
npm install
```

## Run

Start the local AI proxy in one PowerShell window:

```powershell
npm run ai-server
```

By default, if `OPENAI_API_KEY` is not present, the proxy uses the local Codex CLI bridge:

```text
browser upload -> localhost:8787 -> codex exec -m gpt-5.5 --ephemeral --image --output-schema
```

That uses the existing Codex/ChatGPT login on this machine. It does not put a key in browser
code, project files, or persistent environment variables. The run is slower than the API path
because it starts a Codex exec process for each image.

The bridge pins `gpt-5.5` with low reasoning effort for the fastest available 5.5 mode. Override
with `DISEASE_SCOUT_CODEX_MODEL` or `DISEASE_SCOUT_CODEX_REASONING_EFFORT` only when needed.

Start the web simulator:

```powershell
npm run web
```

Uploaded images are sent to the local proxy at `http://localhost:8787/api/scout/analyze`.
The default path calls Codex CLI with the attached image and a JSON output schema. The optional
API path calls the OpenAI Responses API vision endpoint. Both return a structured
`DiseaseScoutObservation`.

Optional API path:

```powershell
$env:OPENAI_API_KEY = "<your API key>"
$env:DISEASE_SCOUT_MODEL_PROVIDER = "openai"
npm run ai-server
```

Or start all Expo targets:

```powershell
npm start
```

Other targets:

```powershell
npm run ios    # macOS + Xcode / Simulator
npm run android
```

## Project layout

| Path       | Role                          |
| ---------- | ----------------------------- |
| `App.js`   | Disease Scout simulator UI    |
| `app.json` | Expo config (name, icons, …) |
| `assets/`  | Icons and splash images       |

## Stack

- Expo SDK **~54**
- React Native **0.81**
- React **19**
