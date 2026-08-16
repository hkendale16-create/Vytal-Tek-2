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

/// Snapshot of a known/paired wearable identity for UI and storage.
class WearableDeviceInfo {
  const WearableDeviceInfo({
    required this.id,
    required this.displayName,
    required this.kind,
    this.model,
    this.firmwareVersion,
    this.batteryPercent,
    this.lastSyncAt,
  });

  final String id;
  final String displayName;
  final VytalDeviceKind kind;
  final String? model;
  final String? firmwareVersion;
  final int? batteryPercent;
  final DateTime? lastSyncAt;

  WearableDeviceInfo copyWith({
    String? displayName,
    VytalDeviceKind? kind,
    String? model,
    String? firmwareVersion,
    int? batteryPercent,
    DateTime? lastSyncAt,
  }) {
    return WearableDeviceInfo(
      id: id,
      displayName: displayName ?? this.displayName,
      kind: kind ?? this.kind,
      model: model ?? this.model,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

/// Normalized wearable interface for current and future Vytal devices.
///
/// Concrete adapters (e.g. QRing) implement this. Capability flags decide
/// which methods are meaningful — unsupported calls should return
/// [ReadingFreshness.notSupported] rather than fabricated values.
abstract class WearableDevice {
  String get adapterId;
  DeviceCapabilities get capabilities;
  Stream<DeviceConnectionState> get connectionState;
  Stream<WearableDeviceInfo?> get deviceInfo;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> sync();

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
