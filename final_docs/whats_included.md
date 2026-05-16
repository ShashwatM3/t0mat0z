"""
FILE: whats_included.md
TOPIC: Whats Included
SUMMARY: This document provides technical details on Whats Included.
It covers: What's included The endpoint serves API reference documentation for both iOS (Swift) and Android (Kotlin) platforms, covering: - `MWDATCore` — App registration, device discovery, session management, and telemetry - `MWDATCamera` — Camera access, reso...
Use this file for implementing features related to this topic.
"""

What's included

The endpoint serves API reference documentation for both iOS (Swift) and Android (Kotlin) platforms, covering:

- `MWDATCore` — App registration, device discovery, session management, and telemetry
- `MWDATCamera` — Camera access, resolution and frame rate selection, and photo capture
- `MWDATMockDevice` — Simulated device for testing without physical hardware

## Tips for effective use

- **Start with the project-level config** — Clone the repo or run the installer. The project-level config gives your AI tool the integration patterns, best practices, and debugging guidance it needs for most tasks.
- **Add the API reference when you need specifics** — If your AI tool can't find a particular method signature or parameter type, point it at the llms.txt endpoint for the full API surface.
- **Be specific in your prompts** — Mention the platform (iOS or Android) and the module you're working with (`MWDATCore`, `MWDATCamera`, or `MWDATMockDevice`).
- **Combine with the guides** — For deeper integration patterns and lifecycle management, point your AI tool at the [integration overview](/docs/build-overview) and platform-specific integration guides ([iOS](/docs/build-integration-ios), [Android](/docs/build-integration-android)).
