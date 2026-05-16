"""
FILE: mock_device_kit.md
TOPIC: Mock Device Kit
SUMMARY: This document provides technical details on Mock Device Kit.
It covers: Mock Device Kit Mock Device Kit is a component of the Device Access Toolkit that helps you build and test integrations for Meta glasses, without the need to access the actual hardware. This kit provides a simulated device that mirrors the capabilitie...
Use this file for implementing features related to this topic.
"""

Mock Device Kit

## Overview

Mock Device Kit is a component of the Device Access Toolkit that helps you build and test integrations for Meta glasses, without the need to access the actual hardware.

This kit provides a simulated device that mirrors the capabilities and behavior of Meta glasses, including camera, media streaming, permissions, and device state changes. You can use it to test your app integrations in a virtual environment. This is useful for rapid iteration, automated testing, and development workflows where physical devices may not be available or practical to use.

**Note:** This page demonstrates how the Mock Device Kit is used in the CameraAccess sample. For information on using Mock Device Kit APIs in your own testing, see [Android testing with Mock Device Kit](/docs/testing-mdk-android) or [iOS testing with Mock Device Kit](/docs/testing-mdk-ios).

## Mock Device Kit in the CameraAccess sample

To connect to a simulated device using the sample app:

1. Tap the **Debug icon** on your mobile device. You will see the Mock Device Kit menu open.
2. Tap **Pair RayBan Meta**. A Mock Device card is then added to the view.
3. Swipe down the **Mock Device Kit** menu. The new device should now be available.

    ![Image showing how to connect Mock Device Kit](/images/mock-device-kit-connecting-to.png){:width="60%"}

## Changing state

Now that your mock device is paired, you can alter the state of your virtual device:

- To simulate powering on the glasses, tap **PowerOn**. The device must change to "Connected" on the main screen.
- To simulate unfolding the glasses, tap **Unfold**. The device is now ready for streaming.
- To simulate putting on the glasses, tap **Don**.

**Note**: CameraAccess automatically checks camera permissions when you start streaming. If permission isn't granted, the app redirects to Meta AI to complete the flow.

## Simulating media streaming

To test your app's media handling capabilities, you can configure the Mock Device Kit with sample media files that simulate video streaming and photo capture from the glasses.
