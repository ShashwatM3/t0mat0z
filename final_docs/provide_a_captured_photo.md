"""
FILE: provide_a_captured_photo.md
TOPIC: Provide A Captured Photo
SUMMARY: This document provides technical details on Provide A Captured Photo.
It covers: Provide a captured photo ```kotlin @Test fun testPhotoCapture() { val device = mockDeviceKit.pairRaybanMeta()...
Use this file for implementing features related to this topic.
"""

Provide a captured photo

```kotlin
@Test
fun testPhotoCapture() {
    val device = mockDeviceKit.pairRaybanMeta()
    prepareForStreaming(device)

    val mockCameraKit = device.getCameraKit()
    mockCameraKit.setCapturedImage(getAssetUri("test_image.png"))

    // Assert on capture results
}
```
