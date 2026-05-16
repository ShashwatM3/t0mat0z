"""
FILE: setup.md
TOPIC: Setup
SUMMARY: This document provides technical details on Setup.
It covers: Setup If you cloned the SDK repo, the config is already included — no extra setup needed. Otherwise, use the installer to add it to an existing project: ```bash ./install-skills.sh claude    # Claude Code only ./install-skills.sh copilot   # GitHub C...
Use this file for implementing features related to this topic.
"""

Setup

If you cloned the SDK repo, the config is already included — no extra setup needed. Otherwise, use the installer to add it to an existing project:

```bash
./install-skills.sh claude    # Claude Code only
./install-skills.sh copilot   # GitHub Copilot only
./install-skills.sh cursor    # Cursor only
./install-skills.sh agents    # AGENTS.md only
./install-skills.sh all       # All tools
```

Or install everything remotely with a single command:

iOS:

```bash
curl -sL https://raw.githubusercontent.com/facebook/meta-wearables-dat-ios/main/install-skills.sh | bash
```

Android:

```bash
curl -sL https://raw.githubusercontent.com/facebook/meta-wearables-dat-android/main/install-skills.sh | bash
```
