"""
FILE: how_to_test_with_mock_device_kit_on_android.md
TOPIC: How To Test With Mock Device Kit On Android
SUMMARY: This document provides technical details on How To Test With Mock Device Kit On Android.
It covers: How to test with Mock Device Kit on Android Use this guide when your Android project already integrates the Wearables Device Access Toolkit and you need to test without physical glasses. The tasks below help you: Create a reusable base rule or test c...
Use this file for implementing features related to this topic.
"""

How to test with Mock Device Kit on Android

## Overview

Use this guide when your Android project already integrates the Wearables Device Access Toolkit and you need to test without physical glasses. The tasks below help you:

## Set up Mock Device Kit in instrumentation tests

Create a reusable base rule or test class that configures Mock Device Kit, grants permissions, and resets state.

```kotlin
import android.content.Context
import androidx.test.ext.junit.rules.ActivityScenarioRule
import androidx.test.platform.app.InstrumentationRegistry
import com.meta.wearable.dat.mockdevice.MockDeviceKit
import com.meta.wearable.dat.mockdevice.api.MockDeviceKitInterface
import org.junit.After
import org.junit.Before
import org.junit.Rule

open class MockDeviceKitTestCase<T : Any>(
    private val activityClass: Class<T>
) {

    @get:Rule
    val scenarioRule = ActivityScenarioRule(activityClass)

    protected lateinit var mockDeviceKit: MockDeviceKitInterface
    protected lateinit var targetContext: Context

    @Before
    open fun setUp() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        targetContext = instrumentation.targetContext
        mockDeviceKit = MockDeviceKit.getInstance(targetContext)

        grantRuntimePermissions()
    }

    @After
    open fun tearDown() {
        mockDeviceKit.reset()
    }

    private fun grantRuntimePermissions() {
        val packageName = targetContext.packageName
        val shell = InstrumentationRegistry.getInstrumentation().uiAutomation
        shell.executeShellCommand("pm grant $packageName android.permission.BLUETOOTH_CONNECT")
        shell.executeShellCommand("pm grant $packageName android.permission.CAMERA")
    }
}
```

## Configure camera data for streaming and capture

Mock camera feeds let you test streaming logic without hardware. The examples below assume assets live under `androidTest/assets`.
