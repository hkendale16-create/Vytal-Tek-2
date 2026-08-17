# QRing SDK — capability notes (from vendor docs)

Source PDFs (uploaded to the agent, not committed as binaries):

- `sdk_ring_external_access_en` — Android external integration guide
- `sdk_ring_external_access_cn` — Chinese counterpart
- `iOS_SDK_SDK_Development_Guide` — `QCBandSDK.framework`

## Packages in repo

Located under `third_party/qring/`:

| Platform | Artifact |
|---|---|
| Android | `third_party/qring/android/qring_sdk_1.0.0.60.aar` (minSdk 26) |
| iOS | `third_party/qring/ios/QCBandSDK.framework` |

Also included: Android/iOS PDF guides and `android/SDKSample.zip` for reference.

## Former status (resolved)

Previously required (now vendored):

| Platform | Artifact |
|---|---|
| Android | `app/libs/qring_sdk_1.0.0.xx.aar` (minSdk 26) |
| iOS | `QCBandSDK.framework` (iOS 9+, `-ObjC`, simulator arch excludes) |

Until these are linked, `QRingWearableAdapter` refuses scan/pair/sync with a user-facing SDK-unavailable error.

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
| Battery | Android `BatteryRsp` 0–100% + charging; iOS level **0–8** (convert carefully) |
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
