import 'dart:async';

import '../models/data_provenance.dart';
import '../models/health_metric.dart';
import 'device_capabilities.dart';
import 'device_connection_state.dart';
import 'wearable_device.dart';

/// Default adapter while no hardware is paired (App-Only Mode).
///
/// Does not fabricate physiological readings.
class UnpairedWearableDevice implements WearableDevice {
  UnpairedWearableDevice();

  final _connection =
      StreamController<DeviceConnectionState>.broadcast();
  final _info = StreamController<WearableDeviceInfo?>.broadcast();

  @override
  String get adapterId => 'unpaired';

  @override
  DeviceCapabilities get capabilities => DeviceCapabilities.none;

  @override
  Stream<DeviceConnectionState> get connectionState async* {
    yield DeviceConnectionState.unpaired;
    yield* _connection.stream;
  }

  @override
  Stream<WearableDeviceInfo?> get deviceInfo async* {
    yield null;
    yield* _info.stream;
  }

  @override
  Future<void> connect() async {
    // Pairing flow is Phase 2. Keep explicit no-op with clear state.
    _connection.add(DeviceConnectionState.unpaired);
  }

  @override
  Future<void> disconnect() async {
    _connection.add(DeviceConnectionState.unpaired);
  }

  @override
  Future<void> sync() async {}

  @override
  Future<HealthMetricReading<int>> getBattery() async => unsupportedReading(
        key: HealthMetricKeys.wearableBattery,
        displayName: 'Battery',
        unit: '%',
      );

  @override
  Future<HealthMetricReading<int>> getHeartRate() async => unsupportedReading(
        key: HealthMetricKeys.heartRate,
        displayName: 'Heart Rate',
        unit: 'BPM',
      );

  @override
  Future<HealthMetricReading<int>> getHrv() async => unsupportedReading(
        key: HealthMetricKeys.hrv,
        displayName: 'HRV',
        unit: 'ms',
      );

  @override
  Future<HealthMetricReading<double>> getTemperature() async =>
      unsupportedReading(
        key: HealthMetricKeys.temperature,
        displayName: 'Temperature',
        unit: '°C',
      );

  @override
  Future<HealthMetricReading<int>> getSpo2() async => unsupportedReading(
        key: HealthMetricKeys.spo2,
        displayName: 'SpO₂',
        unit: '%',
      );

  @override
  Future<HealthMetricReading<Duration>> getSleep() async => unsupportedReading(
        key: HealthMetricKeys.sleepDuration,
        displayName: 'Sleep',
      );

  @override
  Future<void> startWorkoutMonitoring() async {}

  @override
  Future<void> stopWorkoutMonitoring() async {}

  void dispose() {
    _connection.close();
    _info.close();
  }
}

/// Reserved adapter slot for QRing SDK (Phase 2).
///
/// Capabilities stay empty until the official SDK matrix is wired.
class QRingWearableAdapter implements WearableDevice {
  QRingWearableAdapter();

  @override
  String get adapterId => 'qring';

  @override
  DeviceCapabilities get capabilities => DeviceCapabilities.unknownPendingSdk;

  @override
  Stream<DeviceConnectionState> get connectionState =>
      Stream.value(DeviceConnectionState.unpaired);

  @override
  Stream<WearableDeviceInfo?> get deviceInfo => Stream.value(null);

  @override
  Future<void> connect() async {
    throw UnsupportedError(
      'QRing SDK is not integrated yet. Provide official SDK binaries and '
      'capability documentation before enabling pairing.',
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sync() async {
    throw UnsupportedError('QRing SDK is not integrated yet.');
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
    throw UnsupportedError('QRing SDK is not integrated yet.');
  }

  @override
  Future<void> stopWorkoutMonitoring() async {}
}
