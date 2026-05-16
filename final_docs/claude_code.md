"""
FILE: claude_code.md
TOPIC: Claude Code
SUMMARY: This document provides technical details on Claude Code.
It covers: Claude Code [Claude Code](https://docs.anthropic.com/en/docs/claude-code) auto-discovers the `.claude/` directory when you open a project that contains it. No manual configuration is required. Once loaded, Claude Code has full context on the SDK and ...
Use this file for implementing features related to this topic.
"""

Claude Code

## Overview

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) auto-discovers the `.claude/` directory when you open a project that contains it. No manual configuration is required.

Once loaded, Claude Code has full context on the SDK and can help you:

- Set up your project and adding DAT SDK dependencies
- Implement camera streaming, session lifecycle, and permissions
- Write tests with Mock Device Kit
- Debug common integration issues

## Setup

If you cloned the SDK repo, the `.claude/` directory is already included. Otherwise, install it with the CLI:

```bash
./install-skills.sh claude
```

Or install remotely:

iOS:

```bash
curl -sL https://raw.githubusercontent.com/facebook/meta-wearables-dat-ios/main/install-skills.sh | bash -s claude
```

Android:

```bash
curl -sL https://raw.githubusercontent.com/facebook/meta-wearables-dat-android/main/install-skills.sh | bash -s claude
```

## Usage

Start Claude Code in your project directory:

```bash
claude
```

You can then ask it about any DAT SDK topic, have it implement a specific app functionality, or make it write tests — the skills are already loaded:

```text
> How do I set up camera streaming in my Android app?
> Write a test for my session lifecycle using MockDeviceKit
```

## Adding the API reference

The project-level config covers integration patterns and best practices. To also include the full API reference, paste the llms.txt URL directly into your Claude Code prompt:

```text
> Using https://wearables.developer.meta.com/llms.txt?full=true as reference, what parameters does StreamSession accept?
```

Or add it to your `.claude/CLAUDE.md` so it loads automatically:

```markdown
## API Reference
Fetch https://wearables.developer.meta.com/llms.txt?full=true for the Wearables DAT SDK API reference.
```

Claude Code will fetch and read the URL contents automatically when you include it in your prompt.
