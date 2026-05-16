"""
FILE: ai-assisted_development.md
TOPIC: Ai-Assisted Development
SUMMARY: This document provides technical details on Ai-Assisted Development.
It covers: AI-Assisted Development The Wearables Device Access Toolkit provides two levels of AI assistance for developers: 1. **Project-level config** — SDK knowledge (setup guides, streaming patterns, testing, debugging) delivered directly to your AI tool via...
Use this file for implementing features related to this topic.
"""

AI-Assisted Development

## Overview

The Wearables Device Access Toolkit provides two levels of AI assistance for developers:

1. **Project-level config** — SDK knowledge (setup guides, streaming patterns, testing, debugging) delivered directly to your AI tool via config files in the GitHub repos. This is the primary integration path.
2. **API reference endpoint** — The full API surface served via [llms.txt](https://llmstxt.org/) as a supplementary reference for on-demand queries.

## Project-level config

The SDK GitHub repos ship config files for four AI coding tools. Each tool gets the same SDK knowledge — setup guides, streaming patterns, MockDeviceKit testing, session lifecycle, permissions, debugging, and sample app guidance — in whatever format it expects.

| Tool | Config | How it loads |
|------|--------|-------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | `.claude/skills/*.md` | Auto-discovered when you open the project |
| [GitHub Copilot](https://github.com/features/copilot) | `.github/copilot-instructions.md` | Auto-loaded by Copilot in VS Code |
| [Cursor](https://cursor.sh/) | `.cursor/rules/*.mdc` | Auto-loaded with glob-based triggers |
| [AGENTS.md](https://agents.md) | `AGENTS.md` | Universal — auto-discovered by Codex, Gemini CLI, Devin, Windsurf, Jules, and others |

See the dedicated setup guides for each tool: [Claude Code](/docs/ai-assisted-claude-code), [GitHub Copilot](/docs/ai-assisted-github-copilot), [Cursor](/docs/ai-assisted-cursor), [AGENTS.md](/docs/ai-assisted-agents-md).
