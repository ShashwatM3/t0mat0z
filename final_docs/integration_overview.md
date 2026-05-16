"""
FILE: integration_overview.md
TOPIC: Integration Overview
SUMMARY: This document provides technical details on Integration Overview.
It covers: Integration overview The Wearables Device Access Toolkit lets your mobile app integrate with supported AI glasses. An integration establishes a session with the device so your app can access supported sensors on the user’s glasses. Users start a sess...
Use this file for implementing features related to this topic.
"""

Integration overview

## Overview

The Wearables Device Access Toolkit lets your mobile app integrate with supported AI glasses. An integration establishes a session with the device so your app can access supported sensors on the user’s glasses. Users start a session from your app, and then interact through their glasses. They can:

  * Speak to your app through the device's microphones
  * Send video or photos from the device's camera
  * Pause, resume, or stop the session by tapping the glasses, taking them off, or closing the hinges
  * Play audio to the user through the device’s speakers


## Supported devices

Detailed support to devices and version of the Meta AI app and glasses firmware are located in the [Version Dependencies](/docs/version-dependencies) page.

## Integration lifecycle

1. **Registration**: The user connects your app to their wearable device by tapping a call-to-action in your app. This is a one‑time flow. After registration, your app can identify and connect to the user’s device when your app is open. The flow deeplinks the user to the Meta AI app for confirmation, then returns them to your app.
2. **Permissions**: The first time your app attempts to access the user's camera, you must request permission. The user can allow always, allow once, or deny. Your app deeplinks the user to the Meta AI app to confirm the requested permission, and then Meta AI returns them to your app. Microphone access uses the Hands‑Free Profile (HFP), so you request those permissions through iOS or Android platform dialogs.
3. **Session**: After registration and permissions, the user can start a session. During a session, the user engages with your app on their device.

## Sessions

All integrations with Meta AI glasses run as sessions. Only one session can run on a device at a time, and certain features are unavailable while your session is active. Users can pause, resume, or stop your session by closing the hinges, taking the glasses off (when wear detection is enabled), or tapping the glasses. Learn more in [Session lifecycle](/docs/lifecycle-events).

## Key components

`MWDATCore` is the foundation for your integration. It handles:
- App registration with the user’s device and registration state
- Device discovery and management
- Permission requests and state management
- Telemetry

`MWDATCamera` handles camera access and:
- Resolution and frame rate selection
- Starting a video stream and sending/listening for pause, resume, and stop signals
- Receiving frames from devices
- Capturing a single frame during a stream and delivering it to your app
- Photo format

For more, check out our **API reference documentation**: [iOS](https://wearables.developer.meta.com/docs/reference/ios_swift/dat/0.6), [Android](https://wearables.developer.meta.com/docs/reference/android/dat/0.6).
