import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'device_connection_exception.dart';

enum BluetoothReadiness {
  ready,
  permissionDenied,
  permanentlyDenied,
  unsupported,
  unknown,
}

class BluetoothReadinessResult {
  const BluetoothReadinessResult({
    required this.status,
    this.detail,
  });

  final BluetoothReadiness status;
  final String? detail;

  bool get canScan => status == BluetoothReadiness.ready;

  DeviceConnectionException? get asException => switch (status) {
        BluetoothReadiness.ready => null,
        BluetoothReadiness.permissionDenied ||
        BluetoothReadiness.permanentlyDenied =>
          DeviceConnectionException.permissionDenied,
        BluetoothReadiness.unsupported => const DeviceConnectionException(
            code: 'bluetooth_unsupported',
            userMessage:
                'Bluetooth wearable pairing isn’t available on this platform build.',
            canRetry: false,
          ),
        BluetoothReadiness.unknown => DeviceConnectionException.bluetoothOff,
      };
}

/// Checks OS permissions required before scan/pair.
///
/// Does not silently bypass restrictions. Actual radio on/off detection needs
/// platform Bluetooth APIs / vendor SDK (Phase 2 adapter wiring).
class BluetoothReadinessChecker {
  Future<BluetoothReadinessResult> check({bool requestIfNeeded = false}) async {
    if (kIsWeb) {
      return const BluetoothReadinessResult(
        status: BluetoothReadiness.unsupported,
        detail: 'Web build does not support wearable BLE pairing',
      );
    }

    final permissions = <ph.Permission>[
      ph.Permission.bluetooth,
      if (defaultTargetPlatform == TargetPlatform.android) ...[
        ph.Permission.bluetoothScan,
        ph.Permission.bluetoothConnect,
      ],
    ];

    for (final permission in permissions) {
      var status = await permission.status;
      if (requestIfNeeded && status.isDenied) {
        status = await permission.request();
      }
      if (status.isPermanentlyDenied) {
        return BluetoothReadinessResult(
          status: BluetoothReadiness.permanentlyDenied,
          detail: permission.toString(),
        );
      }
      if (!status.isGranted && !status.isLimited && !status.isProvisional) {
        return BluetoothReadinessResult(
          status: BluetoothReadiness.permissionDenied,
          detail: permission.toString(),
        );
      }
    }

    return const BluetoothReadinessResult(status: BluetoothReadiness.ready);
  }
}
