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
browser upload -> configured proxy host:8787 -> codex exec -m gpt-5.5 --ephemeral --image --output-schema
```

That uses the existing Codex/ChatGPT login on this machine. It does not put a key in browser
code, project files, or persistent environment variables. The run is slower than the API path
because it starts a Codex exec process for each image.

The bridge pins `gpt-5.5` with low reasoning effort for the fastest available 5.5 mode. Override
with `DISEASE_SCOUT_CODEX_MODEL` or `DISEASE_SCOUT_CODEX_REASONING_EFFORT` only when needed.

The proxy is provider-swappable behind the same browser endpoint:

```powershell
$env:DISEASE_SCOUT_MODEL_PROVIDER = "codex-cli" # default when no API key is present
$env:DISEASE_SCOUT_MODEL_PROVIDER = "openai"
$env:DISEASE_SCOUT_MODEL_PROVIDER = "gemini"
```

For Gemini, keep the key only in the server process or a local secret helper:

```powershell
$env:GEMINI_API_KEY = "<local key>"
$env:DISEASE_SCOUT_MODEL_PROVIDER = "gemini"
$env:DISEASE_SCOUT_GEMINI_MODEL = "gemini-2.5-flash-lite"
npm run ai-server
```

Do not put API keys in browser code, committed `.env` files, screenshots, or Discord receipts.
All providers are validated against the same `DiseaseScoutObservation` shape before the app receives
the result.

Start the web simulator:

```powershell
npm run web
```

Uploaded images are sent to the proxy at `/api/scout/analyze` on port `8787`.
On the laptop browser this falls back to `http://localhost:8787/api/scout/analyze`.
When the simulator is opened from a phone on the same network, it infers the Expo page host and
uses `http://<laptop-lan-host>:8787/api/scout/analyze`, so the phone does not try to call its own
localhost.

If inference is wrong, set an explicit endpoint before starting Expo:

```powershell
$env:EXPO_PUBLIC_DISEASE_SCOUT_API_URL = "http://<laptop-lan-ip>:8787/api/scout/analyze"
npm run web
```

Before a phone or DAT rehearsal, run the demo network preflight from `prototype\t0mat0z`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\demo-network-preflight.ps1
```

It writes `final_docs\overnight\network-preflight.json` with backend health, web status, listening
ports, LAN candidates, and recommended phone URLs. A Tailscale-only route is logged as a warning
unless the phone is also on Tailscale; venue Wi-Fi still needs a same-network check.

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
