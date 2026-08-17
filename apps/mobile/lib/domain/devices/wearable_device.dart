import '../models/data_provenance.dart';
import '../models/health_metric.dart';
import 'device_capabilities.dart';
import 'device_connection_state.dart';

enum VytalDeviceKind {
  unknown,
  smartRing,
  fitnessBand,
  watch,
  other,
}

extension VytalDeviceKindX on VytalDeviceKind {
  String get label => switch (this) {
        VytalDeviceKind.unknown => 'Device',
        VytalDeviceKind.smartRing => 'Smart ring',
        VytalDeviceKind.fitnessBand => 'Fitness band',
        VytalDeviceKind.watch => 'Watch',
        VytalDeviceKind.other => 'Wearable',
      };
}

/// Snapshot of a known/paired wearable identity for UI and storage.
class WearableDeviceInfo {
  const WearableDeviceInfo({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.adapterId,
    this.model,
    this.firmwareVersion,
    this.batteryPercent,
    this.lastSyncAt,
    this.bluetoothId,
    this.isDemo = false,
  });

  final String id;
  final String displayName;
  final VytalDeviceKind kind;
  final String adapterId;
  final String? model;
  final String? firmwareVersion;
  final int? batteryPercent;
  final DateTime? lastSyncAt;

  /// Vendor/BLE identity when available — never log raw payloads in release.
  final String? bluetoothId;

  /// True when this record came from Demo mode pairing.
  final bool isDemo;

  WearableDeviceInfo copyWith({
    String? displayName,
    VytalDeviceKind? kind,
    String? adapterId,
    String? model,
    String? firmwareVersion,
    int? batteryPercent,
    DateTime? lastSyncAt,
    String? bluetoothId,
    bool? isDemo,
  }) {
    return WearableDeviceInfo(
      id: id,
      displayName: displayName ?? this.displayName,
      kind: kind ?? this.kind,
      adapterId: adapterId ?? this.adapterId,
      model: model ?? this.model,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      bluetoothId: bluetoothId ?? this.bluetoothId,
      isDemo: isDemo ?? this.isDemo,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'kind': kind.name,
        'adapterId': adapterId,
        'model': model,
        'firmwareVersion': firmwareVersion,
        'batteryPercent': batteryPercent,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'bluetoothId': bluetoothId,
        'isDemo': isDemo,
      };

  factory WearableDeviceInfo.fromJson(Map<String, dynamic> json) {
    return WearableDeviceInfo(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? 'Vytal Device',
      kind: VytalDeviceKind.values.firstWhere(
        (e) => e.name == json['kind'],
        orElse: () => VytalDeviceKind.unknown,
      ),
      adapterId: json['adapterId'] as String? ?? 'unknown',
      model: json['model'] as String?,
      firmwareVersion: json['firmwareVersion'] as String?,
      batteryPercent: json['batteryPercent'] as int?,
      lastSyncAt: json['lastSyncAt'] == null
          ? null
          : DateTime.tryParse(json['lastSyncAt'] as String),
      bluetoothId: json['bluetoothId'] as String?,
      isDemo: json['isDemo'] as bool? ?? false,
    );
  }
}

/// Discovered candidate before pairing is confirmed.
class DiscoveredWearable {
  const DiscoveredWearable({
    required this.discoveryId,
    required this.displayName,
    required this.kind,
    required this.adapterId,
    this.rssi,
    this.isDemo = false,
  });

  final String discoveryId;
  final String displayName;
  final VytalDeviceKind kind;
  final String adapterId;
  final int? rssi;
  final bool isDemo;
}

/// Normalized wearable interface for current and future Vytal devices.
abstract class WearableDevice {
  String get adapterId;
  DeviceCapabilities get capabilities;
  Stream<DeviceConnectionState> get connectionState;
  Stream<WearableDeviceInfo?> get deviceInfo;

  Future<void> connect({WearableDeviceInfo? knownDevice});
  Future<void> disconnect();
  Future<void> sync();

  Future<List<DiscoveredWearable>> scan({Duration timeout});

  Future<HealthMetricReading<int>> getBattery();
  Future<HealthMetricReading<int>> getHeartRate();
  Future<HealthMetricReading<int>> getHrv();
  Future<HealthMetricReading<double>> getTemperature();
  Future<HealthMetricReading<int>> getSpo2();
  Future<HealthMetricReading<Duration>> getSleep();

  Future<void> startWorkoutMonitoring();
  Future<void> stopWorkoutMonitoring();
}

HealthMetricReading<T> unsupportedReading<T>({
  required String key,
  required String displayName,
  String? unit,
}) {
  return HealthMetricReading<T>(
    key: key,
    displayName: displayName,
    unit: unit,
    provenance: DataProvenance.wearable,
    freshness: ReadingFreshness.notSupported,
  );
}

HealthMetricReading<T> unavailableReading<T>({
  required String key,
  required String displayName,
  required DataProvenance provenance,
  String? unit,
}) {
  return HealthMetricReading<T>(
    key: key,
    displayName: displayName,
    unit: unit,
    provenance: provenance,
    freshness: ReadingFreshness.unavailable,
  );
}

HealthMetricReading<T> demoReading<T>({
  required String key,
  required String displayName,
  required T value,
  String? unit,
  String? statusLabel,
}) {
  return HealthMetricReading<T>(
    key: key,
    displayName: displayName,
    value: value,
    unit: unit,
    provenance: DataProvenance.demo,
    freshness: ReadingFreshness.live,
    capturedAt: DateTime.now().toUtc(),
    statusLabel: statusLabel ?? 'Demo',
  );
}
