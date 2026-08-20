# QRing / QCBand SDK packages

**Android has moved to HBand / Veepoo** — see `third_party/hband/`.
The Android QRing AAR below is retained only as a historical reference and is
**not** linked from the app Gradle build.

## Android (deprecated for app builds)

| Path | Description |
|---|---|
| `android/qring_sdk_1.0.0.60.aar` | Former QRing Android SDK (unused) |
| `android/SDKSample.zip` | Former vendor Sample project |
| `android/docs/*.pdf` | Former external integration guides |

## iOS (still linked)

| Path | Description |
|---|---|
| `ios/QCBandSDK.framework` | Official QCBand / QRing iOS SDK |
| `ios/docs/iOS_SDK_Development_Guide.pdf` | Development guide |
| `ios/docs/QCBandSDKDemo_README.md` | Demo README |

Primary APIs: `QCSDKManager`, `QCSDKCmdCreator` (umbrella `QCBandSDK.h`).

Linked from the Runner Xcode project (`-ObjC`) and hosted by `QRingPlugin`.
For a matching HBand iOS stack, use
[HBandSDK/iOS_Ble_SDK](https://github.com/HBandSDK/iOS_Ble_SDK).

## Notes

- Do not invent sensor values. Capability flags from the device gate every metric.
- See also `docs/qring-sdk-notes.md` and `third_party/hband/README.md`.
