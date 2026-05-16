"""
FILE: provide_a_mock_video_feed.md
TOPIC: Provide A Mock Video Feed
SUMMARY: This document provides technical details on Provide A Mock Video Feed.
It covers: Provide a mock video feed ```kotlin @Test fun testCameraStreaming() { val device = mockDeviceKit.pairRaybanMeta()...
Use this file for implementing features related to this topic.
"""

Provide a mock video feed

```kotlin
@Test
fun testCameraStreaming() {
    val device = mockDeviceKit.pairRaybanMeta()
    prepareForStreaming(device)

    val mockCameraKit = device.getCameraKit()
    mockCameraKit.setCameraFeed(getAssetUri("test_video.mp4"))

    // Assert on streaming state in your UI
}
```
