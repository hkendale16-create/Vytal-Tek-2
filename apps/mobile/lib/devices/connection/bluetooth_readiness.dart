import 'package:permission_handler/permission_handler.dart' as ph;

import 'device_connection_exception.dart';
import 'pairing_platform.dart';

enum BluetoothReadiness {
  ready,
  permissionDenied,
  permanentlyDenied,
  unsupported,
  bluetoothOff,
  unknown,
}

class BluetoothReadinessResult {
  const BluetoothReadinessResult({
    required this.status,
    this.detail,
    this.userMessage,
  });

  final BluetoothReadiness status;
  final String? detail;
  final String? userMessage;

  bool get canScan => status == BluetoothReadiness.ready;

  DeviceConnectionException? get asException => switch (status) {
        BluetoothReadiness.ready => null,
        BluetoothReadiness.permissionDenied ||
        BluetoothReadiness.permanentlyDenied =>
          DeviceConnectionException.permissionDenied,
        BluetoothReadiness.unsupported => DeviceConnectionException(
            code: 'bluetooth_unsupported',
            userMessage: userMessage ??
                PairingPlatform.limitationMessage(demoModeEnabled: false),
            canRetry: false,
          ),
        BluetoothReadiness.bluetoothOff => DeviceConnectionException.bluetoothOff,
        BluetoothReadiness.unknown => DeviceConnectionException.bluetoothOff,
      };
}

/// Checks OS permissions required before scan/pair.
///
/// Web and desktop are called out separately. Android/iOS proceed to the
/// real permission + QRing scan path.
class BluetoothReadinessChecker {
  Future<BluetoothReadinessResult> check({bool requestIfNeeded = false}) async {
    if (!PairingPlatform.blePairingSupported) {
      return BluetoothReadinessResult(
        status: BluetoothReadiness.unsupported,
        detail: PairingPlatform.shortName,
        userMessage: PairingPlatform.limitationMessage(demoModeEnabled: false),
      );
    }

    final permissions = <ph.Permission>[
      if (PairingPlatform.isIOS) ph.Permission.bluetooth,
      if (PairingPlatform.isAndroid) ...[
        ph.Permission.bluetoothScan,
        ph.Permission.bluetoothConnect,
        ph.Permission.locationWhenInUse,
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

    if (await _isBluetoothOff()) {
      return BluetoothReadinessResult(
        status: BluetoothReadiness.bluetoothOff,
        detail: 'adapter_off',
        userMessage: DeviceConnectionException.bluetoothOff.userMessage,
      );
    }

    return const BluetoothReadinessResult(status: BluetoothReadiness.ready);
  }

  Future<bool> _isBluetoothOff() async {
    try {
      final service = await ph.Permission.bluetooth.serviceStatus;
      return service == ph.ServiceStatus.disabled;
    } catch (_) {
      return false;
    }
  }
}
