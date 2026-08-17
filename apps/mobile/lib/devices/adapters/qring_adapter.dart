import 'dart:async';

import '../../domain/devices/device_capabilities.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../connection/device_connection_exception.dart';
import '../qring/qring_capability_matrix.dart';

/// QRing / QCBand adapter.
///
/// Official packages (`qring_sdk_*.aar`, `QCBandSDK.framework`) are not yet in
/// this repo. Until they are linked, connect/scan/sync fail with a clear
/// user-facing SDK-unavailable error — never fake vitals.
///
/// When the native bridge lands, map live `DeviceSupportFunctionRsp` /
/// `SetTimeRsp` fields into [supportFlags] and expose readings only for
/// supported capabilities.
class QRingWearableAdapter implements WearableDevice {
  QRingWearableAdapter({
    WearableDeviceInfo? knownDevice,
    QRingDeviceSupportFlags supportFlags = QRingDeviceSupportFlags.pending,
  })  : _knownDevice = knownDevice,
        _supportFlags = supportFlags;

  final WearableDeviceInfo? _knownDevice;
  QRingDeviceSupportFlags _supportFlags;

  final _connection = StreamController<DeviceConnectionState>.broadcast();
  final _info = StreamController<WearableDeviceInfo?>.broadcast();

  QRingDeviceSupportFlags get supportFlags => _supportFlags;

  void updateSupportFlags(QRingDeviceSupportFlags flags) {
    _supportFlags = flags;
  }

  @override
  String get adapterId => 'qring';

  @override
  DeviceCapabilities get capabilities => _supportFlags.toDeviceCapabilities();

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

  HealthMetricReading<T> _gated<T>({
    required bool supported,
    required String key,
    required String displayName,
    String? unit,
  }) {
    if (!supported) {
      return unsupportedReading(
        key: key,
        displayName: displayName,
        unit: unit,
      );
    }
    return unavailableReading(
      key: key,
      displayName: displayName,
      provenance: DataProvenance.wearable,
      unit: unit,
    );
  }

  @override
  Future<HealthMetricReading<int>> getBattery() async {
    // Supported by both platforms when connected; value unavailable until SDK.
    return unavailableReading(
      key: HealthMetricKeys.wearableBattery,
      displayName: 'Battery',
      provenance: DataProvenance.wearable,
      unit: '%',
    );
  }

  @override
  Future<HealthMetricReading<int>> getHeartRate() async {
    return _gated(
      supported: capabilities.supportsHeartRate,
      key: HealthMetricKeys.heartRate,
      displayName: 'Heart Rate',
      unit: 'BPM',
    );
  }

  @override
  Future<HealthMetricReading<int>> getHrv() async {
    return _gated(
      supported: capabilities.supportsHrv,
      key: HealthMetricKeys.hrv,
      displayName: 'HRV',
      unit: 'ms',
    );
  }

  @override
  Future<HealthMetricReading<double>> getTemperature() async {
    return _gated(
      supported: capabilities.supportsTemperature,
      key: HealthMetricKeys.temperature,
      displayName: 'Temperature',
      unit: '°C',
    );
  }

  @override
  Future<HealthMetricReading<int>> getSpo2() async {
    return _gated(
      supported: capabilities.supportsSpo2,
      key: HealthMetricKeys.spo2,
      displayName: 'SpO₂',
      unit: '%',
    );
  }

  @override
  Future<HealthMetricReading<Duration>> getSleep() async {
    return _gated(
      supported: capabilities.supportsSleep,
      key: HealthMetricKeys.sleepDuration,
      displayName: 'Sleep',
    );
  }

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
