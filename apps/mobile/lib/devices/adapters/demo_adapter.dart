import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/devices/device_capabilities.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../connection/device_connection_exception.dart';

/// Explicit Demo-mode wearable for connection lifecycle testing.
///
/// All readings use [DataProvenance.demo]. Never use outside Demo mode.
class DemoWearableAdapter implements WearableDevice {
  DemoWearableAdapter({WearableDeviceInfo? knownDevice})
      : _infoValue = knownDevice;

  static const adapterKey = 'demo';

  /// Demo capability set for UI review — still labeled Demo, not production.
  static const demoCapabilities = DeviceCapabilities(
    supportsHeartRate: true,
    supportsRealtimeHeartRate: true,
    supportsBattery: true,
    supportsHrv: true,
    supportsSpo2: true,
    supportsTemperature: true,
    supportsSleep: true,
    supportsSteps: true,
    supportsCalories: true,
  );

  WearableDeviceInfo? _infoValue;
  DeviceConnectionState _state = DeviceConnectionState.unpaired;

  final _connection = StreamController<DeviceConnectionState>.broadcast();
  final _info = StreamController<WearableDeviceInfo?>.broadcast();

  @override
  String get adapterId => adapterKey;

  @override
  DeviceCapabilities get capabilities => demoCapabilities;

  @override
  Stream<DeviceConnectionState> get connectionState async* {
    yield _state;
    yield* _connection.stream;
  }

  @override
  Stream<WearableDeviceInfo?> get deviceInfo async* {
    yield _infoValue;
    yield* _info.stream;
  }

  void _setState(DeviceConnectionState next) {
    _state = next;
    _connection.add(next);
  }

  @override
  Future<List<DiscoveredWearable>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    _setState(DeviceConnectionState.scanning);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _setState(
      _infoValue == null
          ? DeviceConnectionState.disconnected
          : DeviceConnectionState.connected,
    );
    return const [
      DiscoveredWearable(
        discoveryId: 'demo-ring-01',
        displayName: 'Vytal Ring (Demo)',
        kind: VytalDeviceKind.smartRing,
        adapterId: adapterKey,
        rssi: -48,
        isDemo: true,
      ),
      DiscoveredWearable(
        discoveryId: 'demo-band-01',
        displayName: 'Vytal Band (Demo)',
        kind: VytalDeviceKind.fitnessBand,
        adapterId: adapterKey,
        rssi: -61,
        isDemo: true,
      ),
    ];
  }

  @override
  Future<void> connect({WearableDeviceInfo? knownDevice}) async {
    _setState(DeviceConnectionState.pairing);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final device = knownDevice ??
        WearableDeviceInfo(
          id: const Uuid().v4(),
          displayName: 'Vytal Ring (Demo)',
          kind: VytalDeviceKind.smartRing,
          adapterId: adapterKey,
          model: 'Demo Ring',
          firmwareVersion: '0.0.0-demo',
          batteryPercent: 76,
          bluetoothId: 'demo:00:11:22',
          isDemo: true,
        );
    _infoValue = device.copyWith(isDemo: true, adapterId: adapterKey);
    _info.add(_infoValue);
    _setState(DeviceConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    _setState(DeviceConnectionState.disconnected);
  }

  @override
  Future<void> sync() async {
    if (_state != DeviceConnectionState.connected &&
        _state != DeviceConnectionState.syncing) {
      throw DeviceConnectionException.deviceNotNearby;
    }
    _setState(DeviceConnectionState.syncing);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final battery = await getBattery();
    _infoValue = _infoValue?.copyWith(
      lastSyncAt: DateTime.now().toUtc(),
      batteryPercent: battery.value,
    );
    _info.add(_infoValue);
    _setState(DeviceConnectionState.connected);
  }

  @override
  Future<HealthMetricReading<int>> getBattery() async {
    if (_infoValue == null) {
      return unavailableReading(
        key: HealthMetricKeys.wearableBattery,
        displayName: 'Battery',
        provenance: DataProvenance.demo,
        unit: '%',
      );
    }
    final value = _infoValue!.batteryPercent ?? 76;
    return demoReading(
      key: HealthMetricKeys.wearableBattery,
      displayName: 'Battery',
      value: value,
      unit: '%',
      statusLabel: 'Demo',
    );
  }

  @override
  Future<HealthMetricReading<int>> getHeartRate() async {
    if (!capabilities.supportsHeartRate || _infoValue == null) {
      return unsupportedReading(
        key: HealthMetricKeys.heartRate,
        displayName: 'Heart Rate',
        unit: 'BPM',
      );
    }
    return demoReading(
      key: HealthMetricKeys.heartRate,
      displayName: 'Heart Rate',
      value: 72,
      unit: 'BPM',
      statusLabel: 'Demo',
    );
  }

  @override
  Future<HealthMetricReading<int>> getHrv() async {
    if (_infoValue == null) {
      return unsupportedReading(
        key: HealthMetricKeys.hrv,
        displayName: 'HRV',
        unit: 'ms',
      );
    }
    return demoReading(
      key: HealthMetricKeys.hrv,
      displayName: 'HRV',
      value: 65,
      unit: 'ms',
      statusLabel: 'Demo',
    );
  }

  @override
  Future<HealthMetricReading<double>> getTemperature() async {
    if (_infoValue == null) {
      return unsupportedReading(
        key: HealthMetricKeys.temperature,
        displayName: 'Temperature',
        unit: '°C',
      );
    }
    return demoReading(
      key: HealthMetricKeys.temperature,
      displayName: 'Temperature',
      value: 36.9,
      unit: '°C',
      statusLabel: 'Demo',
    );
  }

  @override
  Future<HealthMetricReading<int>> getSpo2() async {
    if (_infoValue == null) {
      return unsupportedReading(
        key: HealthMetricKeys.spo2,
        displayName: 'SpO₂',
        unit: '%',
      );
    }
    return demoReading(
      key: HealthMetricKeys.spo2,
      displayName: 'SpO₂',
      value: 98,
      unit: '%',
      statusLabel: 'Demo',
    );
  }

  @override
  Future<HealthMetricReading<Duration>> getSleep() async {
    if (_infoValue == null) {
      return unsupportedReading(
        key: HealthMetricKeys.sleepDuration,
        displayName: 'Sleep',
      );
    }
    return demoReading(
      key: HealthMetricKeys.sleepDuration,
      displayName: 'Sleep',
      value: const Duration(hours: 7, minutes: 12),
      statusLabel: 'Demo',
    );
  }

  @override
  Future<void> startWorkoutMonitoring() async {}

  @override
  Future<void> stopWorkoutMonitoring() async {}

  void dispose() {
    _connection.close();
    _info.close();
  }
}
