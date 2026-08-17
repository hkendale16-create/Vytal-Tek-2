# QRing SDK — capability notes (from vendor docs)

Source packages live under `third_party/qring/` (also PDF guides in
`android/docs` and `ios/docs`).

## Packages in repo

| Platform | Artifact |
|---|---|
| Android | `third_party/qring/android/qring_sdk_1.0.0.60.aar` (minSdk 26) |
| iOS | `third_party/qring/ios/QCBandSDK.framework` |

## Native bridge (linked)

Flutter MethodChannel `com.vytaltek.qring/methods` + EventChannel
`com.vytaltek.qring/events`:

| Platform | Host |
|---|---|
| Android | `VytalTekApplication` + `QRingSdkHost` (`BleOperateManager`) |
| iOS | `QRingPlugin` (CoreBluetooth scan/connect + `QCSDKManager` / `QCSDKCmdCreator`) |

`QRingWearableAdapter` calls the bridge for scan / connect / sync / metrics.
Capabilities are cached from SetTime + DeviceSupport (Android) or `setTime`
featureList (iOS) before health queries. Unsupported metrics stay
`notSupported` / null — never fabricated.

## Connection lifecycle (Android)

1. Init `BleOperateManager` in `Application.onCreate`
2. Register `QCBluetoothCallbackCloneReceiver` dynamically
3. Scan → connect → on service discovered → `LargeDataHandler.initEnable()`
4. **Serially** send `SetTimeReq` then `DeviceSupportReq`
5. Cache capability flags **before** any health queries
6. Handle `supportBlePair` for system bonding vs soft disconnect

## Documented metrics (capability-gated)

| Metric | Notes |
|---|---|
| Battery | Android `BatteryRsp` 0–100% + charging; iOS may be discrete 0–8 (convert carefully) |
| Heart rate | Timed history + manual; realtime needs `mSupportAppMeasure` / `RealTimeHeartRate` |
| SpO₂ | Setting + manual / interval; PPG raw available |
| HRV | Setting + measurement (`QCMeasuringTypeHRV`) |
| Temperature | Skin / interval / manual; capability flags required |
| Stress / pressure | SDK “pressure” measurement |
| Blood pressure | Timed + manual (not a Vytal primary UI metric unless gated) |
| Steps / calories / distance | Daily totals + detail sport sync |
| Sleep | Stages: awake / light / deep / REM / not worn; score helpers may be app-side |
| Firmware OTA | Documented Sample flow |
| Respiratory rate | **Not** documented as a first-class SDK metric → keep unsupported |

## Permissions

- Android: Bluetooth + **location** (required for BLE scan per official guide)
- iOS: `NSBluetoothAlwaysUsageDescription` / peripheral usage strings

## Vytal mapping

See `apps/mobile/lib/devices/qring/qring_capability_matrix.dart`.
