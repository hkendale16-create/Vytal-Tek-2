# HBand / Veepoo SDK — capability notes

Android is wired to [HBandSDK/Android_Ble_SDK](https://github.com/HBandSDK/Android_Ble_SDK)
(Veepoo `VPOperateManager`). Artifacts live under `third_party/hband/`.

iOS still uses the vendored QCBand / QRing framework until
[HBandSDK/iOS_Ble_SDK](https://github.com/HBandSDK/iOS_Ble_SDK) is integrated.

## Packages in repo

| Platform | Artifact |
|---|---|
| Android | `third_party/hband/android/jar_core/*.aar` + `jar_base/*` + `jniLibs` |
| iOS (current) | `third_party/qring/ios/QCBandSDK.framework` |

## Native bridge (linked)

Flutter MethodChannel `com.vytaltek.qring/methods` + EventChannel
`com.vytaltek.qring/events` (names kept for Dart compatibility):

| Platform | Host |
|---|---|
| Android | `VytalTekApplication` + `HBandSdkHost` (`VPOperateManager`) |
| iOS | `QRingPlugin` (CoreBluetooth + `QCSDKManager` / `QCSDKCmdCreator`) |

`QRingWearableAdapter` calls the bridge for scan / connect / sync / metrics.
Capabilities are cached from `confirmDevicePwd` → `FunctionDeviceSupportData`
(Android) or `setTime` featureList (iOS) before health queries. Unsupported
metrics stay `notSupported` / null — never fabricated.

## Connection lifecycle (Android / HBand)

1. Init `VPOperateManager` in `Application.onCreate`
2. Declare `com.inuker.bluetooth.library.BluetoothService` in the manifest
3. Scan → `connectDevice` → notify success
4. **Serially** `confirmDevicePwd("0000")` then `syncPersonInfo`
5. Cache capability flags **before** any health queries
6. Never run concurrent device commands

## Documented metrics (capability-gated)

| Metric | Notes |
|---|---|
| Battery | `readBattery` → percent or discrete level |
| Heart rate | Live via `startDetectHeart` / `stopDetectHeart` |
| SpO₂ | `readSpo2hOrigin` when `spo2H` supported |
| HRV | `readHRVOrigin` when HRV function supported |
| Temperature | `readTemptureDataBySetting` when temp function supported |
| Stress / pressure | Mapped from Veepoo fatigue support flag |
| Blood pressure | Capability-gated; not a primary Vytal UI metric unless gated |
| Steps / calories / distance | `readSportStep` |
| Sleep | `readSleepDataSingleDay` (`allSleepTime` minutes) |
| Firmware OTA | Nordic / JieLi / Bluetrum / Goodix paths in vendor demo |

## Permissions

- Android: Bluetooth + **location** (BLE scan on older APIs); Android 12+
  `BLUETOOTH_SCAN` with `neverForLocation`
- iOS: `NSBluetoothAlwaysUsageDescription` / peripheral usage strings

## Vytal mapping

See `apps/mobile/lib/devices/qring/qring_capability_matrix.dart`.
