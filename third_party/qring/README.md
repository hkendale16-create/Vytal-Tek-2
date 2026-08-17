# QRing / QCBand SDK packages

Vendored from the uploads on `main` (opaque zip hashes) and organized for Vytal Tek.

## Android

| Path | Description |
|---|---|
| `android/qring_sdk_1.0.0.60.aar` | Official QRing Android SDK |
| `android/SDKSample.zip` | Vendor Sample project (reference) |
| `android/docs/*.pdf` | External integration guides (EN/CN) |

Primary Java entry points (inside AAR): `com.oudmon.ble.base.bluetooth.BleOperateManager`, command handlers, etc.

## iOS

| Path | Description |
|---|---|
| `ios/QCBandSDK.framework` | Official QCBand / QRing iOS SDK |
| `ios/docs/iOS_SDK_Development_Guide.pdf` | Development guide |
| `ios/docs/QCBandSDKDemo_README.md` | Demo README |

Primary APIs: `QCSDKManager`, `QCSDKCmdCreator` (umbrella `QCBandSDK.h`).

## Notes

- Do not invent sensor values. Capability flags from the device gate every metric.
- Android BLE scan requires location permission.
- iOS battery is a discrete 0–8 level; Android battery is 0–100%.
- See also `docs/qring-sdk-notes.md` in the repo root docs folder.
