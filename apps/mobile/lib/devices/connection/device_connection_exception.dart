/// User-facing wearable connection / sync failures.
///
/// Never surface raw BLE codes (e.g. "GATT 133") in UI copy.
class DeviceConnectionException implements Exception {
  const DeviceConnectionException({
    required this.code,
    required this.userMessage,
    this.technicalDetail,
    this.canRetry = true,
  });

  final String code;
  final String userMessage;
  final String? technicalDetail;
  final bool canRetry;

  @override
  String toString() =>
      'DeviceConnectionException($code): $userMessage'
      '${technicalDetail == null ? '' : ' [$technicalDetail]'}';

  static const sdkUnavailable = DeviceConnectionException(
    code: 'sdk_unavailable',
    userMessage:
        'Vytal can’t reach the wearable SDK on this platform yet. Use an Android or iOS device, or enable Demo mode.',
    technicalDetail:
        'QRing native bridge unavailable (MissingPlugin / unsupported platform)',
    canRetry: false,
  );

  static const bluetoothOff = DeviceConnectionException(
    code: 'bluetooth_off',
    userMessage:
        'Bluetooth is turned off. Turn it on, then try connecting again.',
  );

  static const permissionDenied = DeviceConnectionException(
    code: 'permission_denied',
    userMessage:
        'Vytal needs Bluetooth permission to find and connect your device. You can enable it in Settings → Permissions.',
  );

  static const deviceNotNearby = DeviceConnectionException(
    code: 'device_not_nearby',
    userMessage:
        'We couldn’t reconnect to your Vytal device. Make sure it is nearby, charged, and Bluetooth is on.',
  );

  static const demoRequired = DeviceConnectionException(
    code: 'demo_required',
    userMessage:
        'Demo wearable pairing is only available when Demo mode is enabled in Settings.',
    canRetry: false,
  );

  static const alreadyConnected = DeviceConnectionException(
    code: 'already_connected',
    userMessage: 'A device is already connected. Disconnect it first to pair another.',
    canRetry: false,
  );
}
