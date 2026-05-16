"""
FILE: practical_implications.md
TOPIC: Practical Implications
SUMMARY: This document provides technical details on Practical Implications.
It covers: Practical implications You don't track which specific device has permissions. Permission checks return granted if _any_ connected device has approved. If all devices disconnect, permission checks will indicate unavailability. Users manage permissions...
Use this file for implementing features related to this topic.
"""

Practical implications

You don't track which specific device has permissions. Permission checks return granted if _any_ connected device has approved. If all devices disconnect, permission checks will indicate unavailability. Users manage permissions per device in the Meta AI app.

## Distribution and registration

Testing vs. production have different permission requirements. When developer mode is activated, registration is always allowed. When a build is distributed, users must be in the proper release channel to get the app. This is controlled by the `MWDAT` application ID.

**Note:** For security purposes, only one 3rd party app can remain registered at a time in Developer Mode. Registering a new app will automatically unregister any previously registered app.

- For setting up developer mode, see [Getting started with the Wearables Device Access Toolkit](/docs/getting-started-toolkit).
- For details on creating release channels, see [Manage projects in Developer Center](/docs/manage-projects).
  - This page also explains where to find the `APPLICATION_ID` that must be added to your production manifest/bundle configuration.
