"""
FILE: how_to_test_with_mock_device_kit_on_ios.md
TOPIC: How To Test With Mock Device Kit On Ios
SUMMARY: This document provides technical details on How To Test With Mock Device Kit On Ios.
It covers: How to test with Mock Device Kit on iOS Use this guide when your iOS project already integrates the Wearables Device Access Toolkit and you need to test without physical glasses. Create a reusable base rule or test class that configures Mock Device K...
Use this file for implementing features related to this topic.
"""

How to test with Mock Device Kit on iOS

## Overview

Use this guide when your iOS project already integrates the Wearables Device Access Toolkit and you need to test without physical glasses.

## Set up Mock Device Kit in XCTest

Create a reusable base rule or test class that configures Mock Device Kit, grants permissions, and resets state.

```swift
import XCTest
import MetaWearablesDAT

@MainActor
class MockDeviceKitTestCase: XCTestCase {
    private var mockDevice: MockRaybanMeta?
    private var cameraKit: MockCameraKit?

    override func setUp() async throws {
        try await super.setUp()

        try? Wearables.configure()
        mockDevice = MockDeviceKit.shared.pairRaybanMeta()
        cameraKit = mockDevice?.getCameraKit()
    }

    override func tearDown() async throws {
        MockDeviceKit.shared.pairedDevices.forEach { device in
            MockDeviceKit.shared.unpairDevice(device)
        }
        mockDevice = nil
        cameraKit = nil
        try await super.tearDown()
    }
}
```

## Configure camera feeds for streaming tests

Mock camera feeds let you verify streaming and capture workflows without video hardware.
