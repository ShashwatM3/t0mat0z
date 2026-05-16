"""
FILE: use_device_microphones_and_speakers.md
TOPIC: Use Device Microphones And Speakers
SUMMARY: This document provides technical details on Use Device Microphones And Speakers.
It covers: Use device microphones and speakers Device audio uses two Bluetooth profiles: - A2DP (Advanced Audio Distribution Profile) for high‑quality, output‑only media - HFP (Hands‑Free Profile) for two‑way voice communication **Note on Audio Quality:** HFP s...
Use this file for implementing features related to this topic.
"""

Use device microphones and speakers

## Overview

Device audio uses two Bluetooth profiles:

- A2DP (Advanced Audio Distribution Profile) for high‑quality, output‑only media
- HFP (Hands‑Free Profile) for two‑way voice communication

**Note on Audio Quality:** HFP streams audio at 8kHz in mono. The wearable device's microphones use beamforming to isolate and clarify the wearer's voice, which significantly reduces the volume of ambient sounds and other speakers. This is an expected limitation.

## Integrating sessions with HFP

Wearables Device Access Toolkit sessions share microphone and speaker access with the system Bluetooth stack on the glasses.
## iOS sample code

```swift
// Set up the audio session
let audioSession = AVAudioSession.sharedInstance()
try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
```

**Note:** When planning to use HFP and streaming simultaneously, ensure that HFP is fully configured before initiating any streaming session that requires audio functionality.

```swift
func startStreamSessionWithAudio() async {
  // Set up the HFP audio session
  startAudioSession()

  // Instead of waiting for a fixed 2 seconds, use a state-based coordination that waits for HFP to be ready
  try? await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)

  // Start the stream session as usual
  await streamSession.start()
}
```

## Android sample code

```kotlin
private fun routeAudioToBluetooth() {
  val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

  // Get list of currently available devices
  val devices = audioManager.availableCommunicationDevices

  // User chooses one of the devices from the list
  val userSelectedDeviceType = AudioDeviceInfo.TYPE_BLUETOOTH_SCO

  var selectedDevice: AudioDeviceInfo? = null
  for (device in devices) {
    if (device.type == userSelectedDeviceType) {
      selectedDevice = device
      break
    }
  }

  if (selectedDevice != null) {
    audioManager.mode = AudioManager.MODE_NORMAL
    audioManager.setCommunicationDevice(selectedDevice)
  }
}
```

For guidance on how to use audio in your app, refer to the corresponding iOS API and Android API docs:

- iOS API: [AVAudioSession](https://developer.apple.com/documentation/AVFAudio/AVAudioSession)

- Android API: [AudioManager](https://developer.android.com/reference/android/media/AudioManager)
