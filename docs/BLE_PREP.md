# BLE & Wearable Preparation — Audit & Hardware Validation

This document records the software-ready BLE architecture and what still requires physical Vytal hardware to validate.

## Why “pairing isn’t available on this platform build” appears

| Environment | Cause |
|-------------|--------|
| **Web / Linux / macOS / Windows** | `PairingPlatform.blePairingSupported` is false — QRing native bridge is Android/iOS only. Message is accurate, not a bug. |
| **Android / iOS native builds** | Pairing is supported. Use a release/debug APK or IPA on hardware (or Demo mode in Settings for UI testing). |
| **Demo mode off + desktop CI** | Expected: `sdk_unavailable` / platform limitation. |

The old compiled web string “platform build” came from an earlier web bundle; current Dart copy is in `pairing_platform.dart`.

## Architecture (software-ready)

```
DevicesScreen / Workouts / Today
        ↓
DeviceConnectionController  ← single WearableDevice adapter instance
        ↓
QRingWearableAdapter | DemoWearableAdapter | UnpairedWearableDevice
        ↓
MethodChannelQRingNativeApi (singleton) → QRingSdkHost.kt | QRingPlugin.swift
        ↓
qring_sdk_1.0.0.60.aar | QCBandSDK.framework
```

- **Persistence:** `vytal.app_session.v1` (paired device + connection state), `vytal.devices.registry.v1`
- **States:** unpaired → searching (scanning) → devicesFound → connecting → connected → synchronizing → **ready** → disconnected / reconnecting / error
- **Auto-reconnect:** launch bootstrap + unexpected GATT drop + app resume (4s backoff, respects user disconnect/forget)
- **Live HR (workout):** Android `RealTimeHeartRate` start/poll/stop; iOS `beginRealTimeHeartRate` + `realTimeHeartRate` callback → EventChannel `heartRateUpdate`
- **Demo mode:** clearly labeled Demo provenance; never mixed with production session without user enabling Demo in Settings

## Software-ready checklist (implemented)

- [x] Runtime Bluetooth permissions (Android scan/connect/location; iOS bluetooth)
- [x] BLE scan with RSSI + human signal labels
- [x] Connection state machine + UI copy
- [x] Pair / connect / sync / reconnect / disconnect / forget
- [x] Saved device restore on cold start
- [x] Wearable abstraction (`WearableDevice`) for ring / band / watch kinds
- [x] QRing SDK wrapper (scan, connect, sync, battery, capabilities)
- [x] Workout live HR stream hook + fallback poll
- [x] Global connection indicator (tap → My Devices)
- [x] Singleton native bridge (no duplicate EventChannel listeners)

## Hardware validation (requires physical device)

Do **not** mark these as production-verified until tested on real Vytal Tek hardware:

- [ ] Actual BLE discovery of production firmware names
- [ ] GATT service/characteristic behavior under load
- [ ] Real-time HR accuracy and latency (Android poll vs iOS push)
- [ ] HRV / SpO₂ / temperature live vs sync-only paths
- [ ] Reconnection when leaving/returning to range
- [ ] Battery % accuracy vs device UI
- [ ] Background / foreground BLE lifecycle
- [ ] Firmware version string from GATT
- [ ] Android `bleCreateBond` / iOS retrievePeripherals reconnect after kill
- [ ] Workout monitoring with ring on finger during movement

## Developer test mode

Enable **Demo mode** in Settings to exercise the full pair → sync → workout HR flow with labeled demo devices. Demo readings show `Demo` provenance and must not be presented as live wearable data in production sessions.

## Key files

| Area | Path |
|------|------|
| Connection orchestration | `lib/devices/connection/device_connection_controller.dart` |
| QRing adapter | `lib/devices/adapters/qring_adapter.dart` |
| Native Dart bridge | `lib/devices/qring/qring_native_api.dart` |
| Android SDK host | `android/.../qring/QRingSdkHost.kt` |
| iOS plugin | `ios/Runner/QRing/QRingPlugin.swift` |
| My Devices UI | `lib/features/devices/devices_screen.dart` |
| Connection indicator | `lib/features/devices/wearable_connection_indicator.dart` |
| Workout HR | `lib/workouts/workout_controllers.dart` |
