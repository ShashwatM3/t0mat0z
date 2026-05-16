"""
FILE: github_copilot.md
TOPIC: Github Copilot
SUMMARY: This document provides technical details on Github Copilot.
It covers: GitHub Copilot [GitHub Copilot](https://github.com/features/copilot) auto-loads `.github/copilot-instructions.md` when you open a project in VS Code. The SDK knowledge is available in Copilot Chat immediately. Copilot also provides inline completions...
Use this file for implementing features related to this topic.
"""

GitHub Copilot

## Overview

[GitHub Copilot](https://github.com/features/copilot) auto-loads `.github/copilot-instructions.md` when you open a project in VS Code. The SDK knowledge is available in Copilot Chat immediately.

Copilot also provides inline completions as you write DAT SDK code — the project config gives it enough context to suggest correct API usage, parameter names, and patterns.

## Setup

If you cloned the SDK repo, the `.github/copilot-instructions.md` file is already included. Otherwise, install with the CLI:

```bash
./install-skills.sh copilot
```

Or install remotely:

iOS:

```bash
curl -sL https://raw.githubusercontent.com/facebook/meta-wearables-dat-ios/main/install-skills.sh | bash -s copilot
```

Android:

```bash
curl -sL https://raw.githubusercontent.com/facebook/meta-wearables-dat-android/main/install-skills.sh | bash -s copilot
```

## Usage

Use Copilot Chat to ask SDK questions directly:

```text
How do I request camera permissions in my iOS DAT app?
```

## Adding the API reference

The project-level config covers integration patterns and best practices. To also pull in the full API reference during a chat session, paste the URL directly into your Copilot Chat prompt:

```text
Using https://wearables.developer.meta.com/llms.txt?full=true as reference,
what parameters does MWDATCameraSession.startStreaming accept?
```

Copilot Chat fetches and reads URL contents automatically when you include them in your prompt.
