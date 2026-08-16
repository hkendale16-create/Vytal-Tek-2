import 'dart:async';

import '../../devices/connection/device_connection_exception.dart';
import '../../domain/devices/device_capabilities.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';

/// Reserved adapter for the official QRing SDK.
///
/// Capabilities stay empty until vendor docs/binaries confirm real metrics.
/// Production pairing must not invent physiological values.
class QRingWearableAdapter implements WearableDevice {
  QRingWearableAdapter({WearableDeviceInfo? knownDevice})
      : _knownDevice = knownDevice;

  final WearableDeviceInfo? _knownDevice;
  final _connection = StreamController<DeviceConnectionState>.broadcast();
  final _info = StreamController<WearableDeviceInfo?>.broadcast();

  @override
  String get adapterId => 'qring';

  @override
  DeviceCapabilities get capabilities => DeviceCapabilities.unknownPendingSdk;

  @override
  Stream<DeviceConnectionState> get connectionState async* {
    yield DeviceConnectionState.unpaired;
    yield* _connection.stream;
  }

  @override
  Stream<WearableDeviceInfo?> get deviceInfo async* {
    yield _knownDevice;
    yield* _info.stream;
  }

  @override
  Future<List<DiscoveredWearable>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    throw DeviceConnectionException.sdkUnavailable;
  }

  @override
  Future<void> connect({WearableDeviceInfo? knownDevice}) async {
    _connection.add(DeviceConnectionState.pairing);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _connection.add(DeviceConnectionState.error);
    throw DeviceConnectionException.sdkUnavailable;
  }

  @override
  Future<void> disconnect() async {
    _connection.add(DeviceConnectionState.disconnected);
  }

  @override
  Future<void> sync() async {
    throw DeviceConnectionException.sdkUnavailable;
  }

  @override
  Future<HealthMetricReading<int>> getBattery() async => unavailableReading(
        key: HealthMetricKeys.wearableBattery,
        displayName: 'Battery',
        provenance: DataProvenance.wearable,
        unit: '%',
      );

  @override
  Future<HealthMetricReading<int>> getHeartRate() async => unavailableReading(
        key: HealthMetricKeys.heartRate,
        displayName: 'Heart Rate',
        provenance: DataProvenance.wearable,
        unit: 'BPM',
      );

  @override
  Future<HealthMetricReading<int>> getHrv() async => unavailableReading(
        key: HealthMetricKeys.hrv,
        displayName: 'HRV',
        provenance: DataProvenance.wearable,
        unit: 'ms',
      );

  @override
  Future<HealthMetricReading<double>> getTemperature() async =>
      unavailableReading(
        key: HealthMetricKeys.temperature,
        displayName: 'Temperature',
        provenance: DataProvenance.wearable,
        unit: '°C',
      );

  @override
  Future<HealthMetricReading<int>> getSpo2() async => unavailableReading(
        key: HealthMetricKeys.spo2,
        displayName: 'SpO₂',
        provenance: DataProvenance.wearable,
        unit: '%',
      );

  @override
  Future<HealthMetricReading<Duration>> getSleep() async => unavailableReading(
        key: HealthMetricKeys.sleepDuration,
        displayName: 'Sleep',
        provenance: DataProvenance.wearable,
      );

  @override
  Future<void> startWorkoutMonitoring() async {
    throw DeviceConnectionException.sdkUnavailable;
  }

  @override
  Future<void> stopWorkoutMonitoring() async {}

  void dispose() {
    _connection.close();
    _info.close();
  }
}
