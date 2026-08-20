# BLE connect crash fix (Android / HBand)

## Symptom
App crashed when connecting over Bluetooth after the HBand SDK swap.

## Root causes

1. **Double `MethodChannel.Result` reply (primary crash)**  
   Flutter Android crashes with `IllegalStateException: Reply already submitted` if `success`/`error` is called twice on the same connect `Result`.  
   Our handshake could reply more than once because:
   - connect failure **and** notify failure both called `failConnect`
   - person-info callback **and** the 4s fallback both called `completeConnectSuccess`
   - a new connect could race with a delayed callback from the previous attempt

2. **Reply off the UI / platform thread**  
   Veepoo BLE callbacks often run on binder threads. Flutter requires `MethodChannel.Result` to be answered on the main thread.

3. **`SecurityException` not caught**  
   Missing `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (or location on older APIs) during scan/connect could abort the process instead of returning a channel error.

4. **Dart `Completer` double-complete**  
   Event-channel “connected” plus a later `PlatformException` from the method call could fault the Dart side even after a successful connect.

## Fixes
- `connectGeneration` token ignores stale BLE callbacks
- `connectReplySent` AtomicBoolean → **one reply per attempt**
- All connect replies posted on `mainHandler`
- Permission pre-check + try/catch around scan/connect/handshake
- Safer Dart connect Completer / event handling

## Files changed
- `apps/mobile/android/.../hband/HBandSdkHost.kt`
- `apps/mobile/lib/devices/qring/qring_native_api.dart`
