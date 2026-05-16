"""
FILE: adding_to_your_own_project.md
TOPIC: Adding To Your Own Project
SUMMARY: This document provides technical details on Adding To Your Own Project.
It covers: Adding to your own project Use the installer script: Android: ```bash curl -sL https://raw.githubusercontent.com/facebook/meta-wearables-dat-android/main/install-skills.sh | bash -s -- agents...
Use this file for implementing features related to this topic.
"""

Adding to your own project

Use the installer script:

Android:

```bash
curl -sL https://raw.githubusercontent.com/facebook/meta-wearables-dat-android/main/install-skills.sh | bash -s -- agents
```

iOS:

```bash
curl -sL https://raw.githubusercontent.com/facebook/meta-wearables-dat-ios/main/install-skills.sh | bash -s -- agents
```

Or install all tool configs at once:

```bash
curl -sL https://raw.githubusercontent.com/facebook/meta-wearables-dat-android/main/install-skills.sh | bash -s -- all
```

## Other tool configs

The SDK also includes project-level configs for specific AI tools. See the [AI-Assisted Development overview](/ai-assisted/) for the full list.
