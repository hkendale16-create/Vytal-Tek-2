# HBand / Veepoo BLE SDK (Android)

Vendored from [HBandSDK/Android_Ble_SDK](https://github.com/HBandSDK/Android_Ble_SDK).

This replaces the previous QRing / Oudmon Android AAR for Vytal Tek Android builds.

## Artifacts

| Path | Role |
|---|---|
| `android/jar_core/vpbluetooth-1.20.aar` | BLE connection stack (`com.inuker.bluetooth`) |
| `android/jar_core/vpprotocol-2.3.80.15.aar` | Protocol / `VPOperateManager` |
| `android/jar_core/JL_*.aar`, `jl_*.aar`, `BmpConvert_*.aar` | JieLi chip support |
| `android/jar_core/abpartool-release.aar` | Bluetrum chip support |
| `android/jar_base/gson-2.2.4.jar` | Required Gson (exclude Maven gson) |
| `android/jar_base/lib*.aar|jar` | Optional Goodix DFU |
| `android/jniLibs/` | Native libs (`libnative-lib`, Opus) |
| `android/docs/` | Vendor integration notes |

Maven (required by the vendor README):

- `no.nordicsemi.android:mcumgr-core:2.7.4`
- `no.nordicsemi.android:mcumgr-ble:2.7.4`
- `no.nordicsemi.android.support.v18:scanner:1.4.2`
- `androidx.localbroadcastmanager:localbroadcastmanager:1.1.0`

## Connection handshake (required)

All BLE ops go through `VPOperateManager`:

1. `init(applicationContext)`
2. `startScanDevice` → pick MAC
3. `connectDevice` → wait for notify success
4. `confirmDevicePwd` (default `"0000"`) → capability flags
5. `syncPersonInfo` before health reads

Devices do **not** support concurrent commands — serialize health sync.

## App wiring

- Host: `apps/mobile/android/.../hband/HBandSdkHost.kt`
- Linked from `apps/mobile/android/app/build.gradle.kts`
- Manifest service: `com.inuker.bluetooth.library.BluetoothService`

## iOS

This repo only covers Android. For iOS use
[HBandSDK/iOS_Ble_SDK](https://github.com/HBandSDK/iOS_Ble_SDK).
