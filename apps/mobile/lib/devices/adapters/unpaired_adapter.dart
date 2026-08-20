import 'dart:async';

import '../../domain/devices/device_capabilities.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/health_metric.dart';

/// Default adapter while no hardware is paired (App-Only Mode).
class UnpairedWearableDevice implements WearableDevice {
  UnpairedWearableDevice();

  final _connection = StreamController<DeviceConnectionState>.broadcast();
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
  Future<void> connect({WearableDeviceInfo? knownDevice}) async {
    _connection.add(DeviceConnectionState.unpaired);
  }

  @override
  Future<void> disconnect() async {
    _connection.add(DeviceConnectionState.unpaired);
  }

  @override
  Future<void> sync() async {}

  @override
  Future<List<DiscoveredWearable>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) async =>
      const [];

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

  @override
  Stream<int> watchLiveHeartRate() => const Stream.empty();

  void dispose() {
    _connection.close();
    _info.close();
  }
}
