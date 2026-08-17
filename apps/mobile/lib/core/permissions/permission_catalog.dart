import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Catalog entry for Settings → Permissions.
class PermissionDescriptor {
  const PermissionDescriptor({
    required this.id,
    required this.title,
    required this.whyNeeded,
    required this.affectedWhenDenied,
    required this.platformPermission,
    this.opensAppSettingsWhenDenied = true,
    this.unsupportedOnCurrentPlatform = false,
  });

  final String id;
  final String title;
  final String whyNeeded;
  final String affectedWhenDenied;
  final ph.Permission? platformPermission;
  final bool opensAppSettingsWhenDenied;
  final bool unsupportedOnCurrentPlatform;
}

/// Central permission definitions. Request only what Vytal genuinely needs.
abstract final class PermissionCatalog {
  static const bluetooth = PermissionDescriptor(
    id: 'bluetooth',
    title: 'Bluetooth',
    whyNeeded:
        'Connects to your Vytal wearable for syncing and live monitoring.',
    affectedWhenDenied:
        'Device pairing, live readings, and background sync are unavailable.',
    platformPermission: ph.Permission.bluetooth,
  );

  static const bluetoothScan = PermissionDescriptor(
    id: 'bluetooth_scan',
    title: 'Nearby devices',
    whyNeeded: 'Finds Vytal wearables during pairing on modern Android.',
    affectedWhenDenied: 'Vytal cannot discover nearby wearables to pair.',
    platformPermission: ph.Permission.bluetoothScan,
  );

  static const bluetoothConnect = PermissionDescriptor(
    id: 'bluetooth_connect',
    title: 'Bluetooth connect',
    whyNeeded: 'Maintains a secure link to your paired wearable.',
    affectedWhenDenied: 'Paired devices cannot reconnect.',
    platformPermission: ph.Permission.bluetoothConnect,
  );

  static const notifications = PermissionDescriptor(
    id: 'notifications',
    title: 'Notifications',
    whyNeeded:
        'Timer completion, reminders, battery alerts, and optional AI insights.',
    affectedWhenDenied:
        'Reminders and timer alerts will not appear outside the app.',
    platformPermission: ph.Permission.notification,
  );

  static const activity = PermissionDescriptor(
    id: 'activity',
    title: 'Physical activity',
    whyNeeded: 'Improves workout detection and activity summaries on Android.',
    affectedWhenDenied:
        'Automatic workout detection and some activity metrics may be limited.',
    platformPermission: ph.Permission.activityRecognition,
  );

  static const sensors = PermissionDescriptor(
    id: 'sensors',
    title: 'Motion & fitness',
    whyNeeded: 'Supports motion-aware monitoring where the OS requires it.',
    affectedWhenDenied: 'Some motion-based features may be unavailable.',
    platformPermission: ph.Permission.sensors,
  );

  /// Required by the official QRing Android SDK for BLE scanning.
  static const location = PermissionDescriptor(
    id: 'location',
    title: 'Location',
    whyNeeded:
        'Android requires location permission for Bluetooth scanning when pairing a Vytal wearable. Vytal does not use your location for tracking.',
    affectedWhenDenied:
        'Vytal cannot discover nearby wearables to pair on Android.',
    platformPermission: ph.Permission.locationWhenInUse,
  );

  static List<PermissionDescriptor> get core {
    if (kIsWeb) {
      return [
        PermissionDescriptor(
          id: bluetooth.id,
          title: bluetooth.title,
          whyNeeded: bluetooth.whyNeeded,
          affectedWhenDenied: bluetooth.affectedWhenDenied,
          platformPermission: null,
          unsupportedOnCurrentPlatform: true,
        ),
        notifications,
      ];
    }
    return [
      bluetooth,
      if (defaultTargetPlatform == TargetPlatform.android) ...[
        bluetoothScan,
        bluetoothConnect,
        location,
        activity,
      ],
      notifications,
      if (defaultTargetPlatform == TargetPlatform.iOS) sensors,
    ];
  }
}

enum VytalPermissionStatus {
  unknown,
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  notApplicable,
  unsupported,
}

extension VytalPermissionStatusX on VytalPermissionStatus {
  String get label => switch (this) {
        VytalPermissionStatus.unknown => 'Disabled',
        VytalPermissionStatus.granted => 'Enabled',
        VytalPermissionStatus.denied => 'Denied',
        VytalPermissionStatus.permanentlyDenied => 'Permanently Denied',
        VytalPermissionStatus.restricted => 'Restricted',
        VytalPermissionStatus.limited => 'Limited',
        VytalPermissionStatus.notApplicable => 'Not Required',
        VytalPermissionStatus.unsupported => 'Unsupported',
      };

  bool get isEffectivelyGranted =>
      this == VytalPermissionStatus.granted ||
      this == VytalPermissionStatus.limited;
}
