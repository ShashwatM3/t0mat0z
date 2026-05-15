# Hello World (Expo)

Minimal [Expo](https://expo.dev/) + React Native app that shows **Hello, World!** on screen.

From the repository root, enter this folder before installing or starting Expo:

```bash
cd app
```

## Prerequisites

- **Node.js** (LTS recommended) and npm
- **Expo Go** on your Android phone ([Google Play](https://play.google.com/store/apps/details?id=host.exp.exponent))

## Setup

```bash
npm install
```

## Run

Start the dev server:

```bash
npm start
```

Then:

- **Physical Android device**: open Expo Go and scan the QR code from the terminal (phone and computer should be on the same Wi‑Fi), or use tunnel mode if LAN discovery fails.
- **Emulator**: with Android tooling installed, press `a` in the Expo CLI, or run `npm run android`.

Other targets:

```bash
npm run ios    # macOS + Xcode / Simulator
npm run web    # web preview
```

## Project layout

| Path       | Role                          |
| ---------- | ----------------------------- |
| `App.js`   | Main UI                       |
| `app.json` | Expo config (name, icons, …) |
| `assets/`  | Icons and splash images       |

## Stack

- Expo SDK **~54**
- React Native **0.81**
- React **19**
