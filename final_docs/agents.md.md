"""
FILE: agents.md.md
TOPIC: Agents
SUMMARY: This document provides technical details on Agents.
It covers: AGENTS.md [AGENTS.md](https://agents.md) is an open standard for guiding AI coding agents. It provides a universal, tool-agnostic way to give any AI assistant context about your project, using the same SDK knowledge that powers our Claude Code, Copil...
Use this file for implementing features related to this topic.
"""

AGENTS.md

## Overview

[AGENTS.md](https://agents.md) is an open standard for guiding AI coding agents. It provides a universal, tool-agnostic way to give any AI assistant context about your project, using the same SDK knowledge that powers our Claude Code, Copilot, and Cursor configs, in a format supported by 20+ AI tools.

## What is AGENTS.md?

`AGENTS.md` is a predictable, discoverable file at the repo root that any AI coding agent can find and use. Key properties:

- **Standard Markdown** — no required fields or special syntax
- **Closest file wins** — supports nested files for monorepos
- **Open standard** — stewarded by the Linux Foundation's Agentic AI Foundation
- **Widely supported** — works with Codex, Gemini CLI, Devin, Windsurf, Jules, Cursor, VS Code, Zed, Aider, and others

It's complementary to `README.md`, but where README is for humans, AGENTS.md is for AI agents, providing additional context that might otherwise clutter a README.

## Which tools support it?

AGENTS.md is supported by a growing ecosystem of AI coding tools, all of which have support for auto-discover:

* OpenAI Codex
* Google Gemini CLI
* Devin
* Windsurf
* Jules
* Cursor
* VS Code (GitHub Copilot)
* Zed
* Aider

## What's included

The Device Access Toolkit SDK's `AGENTS.md` file contains the same knowledge as our other tool configs — SDK architecture, API patterns, setup instructions, testing guides, and debugging tips — but structured for universal agent consumption:

- **Code style** — Architecture, naming conventions, error handling patterns
- **Dev environment tips** — SDK setup, dependency management, initialization
- **Testing instructions** — MockDeviceKit setup and test patterns
- **Building and streaming** — StreamSession, VideoFrame, photo capture
- **Session management** — Device session states, pause/resume behavior
- **Permissions** — Registration and camera permission flows
- **Debugging** — Common issues, Developer Mode, version compatibility
- **Sample app** — Complete end-to-end integration example

## Setup
