import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/devices/device_capabilities.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../connection/device_connection_exception.dart';
import '../qring/qring_capability_matrix.dart';
import '../qring/qring_native_api.dart';

/// QRing / QCBand adapter backed by the native SDK bridge.
///
/// Never fabricates vitals. Readings come only from [QRingNativeApi] and are
/// gated by live capability flags from SetTime / DeviceSupport (or iOS
/// featureList).
class QRingWearableAdapter implements WearableDevice {
  QRingWearableAdapter({
    WearableDeviceInfo? knownDevice,
    QRingDeviceSupportFlags supportFlags = QRingDeviceSupportFlags.pending,
    QRingNativeApi? nativeApi,
  })  : _knownDevice = knownDevice,
        _supportFlags = supportFlags,
        _native = nativeApi ?? MethodChannelQRingNativeApi();

  WearableDeviceInfo? _knownDevice;
  QRingDeviceSupportFlags _supportFlags;
  final QRingNativeApi _native;

  final _connection = StreamController<DeviceConnectionState>.broadcast();
  final _info = StreamController<WearableDeviceInfo?>.broadcast();

  QRingHealthSnapshot _lastSnapshot = const QRingHealthSnapshot();
  bool _sleepAvailable = false;
  bool _stepsAvailable = false;

  QRingDeviceSupportFlags get supportFlags => _supportFlags;

  void updateSupportFlags(QRingDeviceSupportFlags flags) {
    _supportFlags = flags;
  }

  @override
  String get adapterId => 'qring';

  @override
  DeviceCapabilities get capabilities => _supportFlags.toDeviceCapabilities(
        sleepAvailable: _sleepAvailable || _supportFlags.supportNewSleepProtocol,
        stepsAvailable: _stepsAvailable,
        caloriesAvailable: _stepsAvailable,
        distanceAvailable: _stepsAvailable,
      );

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

  Future<void> _ensureNative() async {
    final available = await _native.isAvailable();
    if (!available) {
      throw DeviceConnectionException.sdkUnavailable;
    }
    await _native.initialize();
  }

  DeviceConnectionException _mapPlatform(Object error) {
    if (error is DeviceConnectionException) return error;
    if (error is PlatformException) {
      return DeviceConnectionException(
        code: error.code,
        userMessage: error.message ??
            'We couldn’t talk to your wearable. Keep it nearby and try again.',
        technicalDetail: error.details?.toString(),
      );
    }
    return DeviceConnectionException(
      code: 'native_error',
      userMessage:
          'We couldn’t talk to your wearable. Keep it nearby and try again.',
      technicalDetail: error.toString(),
    );
  }

  @override
  Future<List<DiscoveredWearable>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await _ensureNative();
    _connection.add(DeviceConnectionState.scanning);
    final seen = <String, DiscoveredWearable>{};
    final sub = _native.startScan(timeout: timeout).listen((result) {
      if (result.deviceId.isEmpty) return;
      seen[result.deviceId] = DiscoveredWearable(
        discoveryId: result.deviceId,
        displayName: result.name.isEmpty ? 'QRing' : result.name,
        kind: VytalDeviceKind.smartRing,
        adapterId: adapterId,
        rssi: result.rssi,
      );
    });
    try {
      await Future<void>.delayed(timeout);
      await _native.stopScan();
    } finally {
      await sub.cancel();
      _connection.add(DeviceConnectionState.disconnected);
    }
    return seen.values.toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
  }

  @override
  Future<void> connect({WearableDeviceInfo? knownDevice}) async {
    await _ensureNative();
    final target = knownDevice ?? _knownDevice;
    final deviceId = target?.bluetoothId;
    if (deviceId == null || deviceId.isEmpty) {
      throw const DeviceConnectionException(
        code: 'missing_device_id',
        userMessage:
            'No wearable identity is available to connect. Scan and pair again.',
        canRetry: false,
      );
    }

    _connection.add(DeviceConnectionState.pairing);
    try {
      final result = await _native.connect(deviceId);
      _supportFlags = result.flags;
      _knownDevice = (target ??
              WearableDeviceInfo(
                id: result.deviceId,
                displayName: result.name,
                kind: VytalDeviceKind.smartRing,
                adapterId: adapterId,
                bluetoothId: result.deviceId,
              ))
          .copyWith(
            displayName: result.name.isNotEmpty ? result.name : null,
            firmwareVersion: result.firmwareVersion,
            bluetoothId: result.deviceId,
          );
      _info.add(_knownDevice);
      _connection.add(DeviceConnectionState.connected);
    } catch (error) {
      _connection.add(DeviceConnectionState.error);
      throw _mapPlatform(error);
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _native.disconnect(
        unbind: _supportFlags.supportBlePair,
      );
    } catch (_) {
      // Best-effort disconnect.
    }
    _connection.add(DeviceConnectionState.disconnected);
  }

  @override
  Future<void> sync() async {
    await _ensureNative();
    _connection.add(DeviceConnectionState.syncing);
    try {
      final snapshot = await _native.syncHealth();
      _lastSnapshot = snapshot;
      _sleepAvailable = snapshot.sleepAvailable || snapshot.sleepMinutes != null;
      _stepsAvailable = snapshot.stepsAvailable || snapshot.steps != null;
      if (snapshot.battery != null && _knownDevice != null) {
        _knownDevice = _knownDevice!.copyWith(
          batteryPercent: snapshot.battery!.percent,
          lastSyncAt: DateTime.now().toUtc(),
        );
        _info.add(_knownDevice);
      }
      _connection.add(DeviceConnectionState.connected);
    } catch (error) {
      _connection.add(DeviceConnectionState.error);
      throw _mapPlatform(error);
    }
  }

  HealthMetricReading<T> _gated<T>({
    required bool supported,
    required String key,
    required String displayName,
    String? unit,
    T? value,
  }) {
    if (!supported) {
      return unsupportedReading(
        key: key,
        displayName: displayName,
        unit: unit,
      );
    }
    if (value == null) {
      return unavailableReading(
        key: key,
        displayName: displayName,
        provenance: DataProvenance.wearable,
        unit: unit,
      );
    }
    return HealthMetricReading<T>(
      key: key,
      displayName: displayName,
      value: value,
      unit: unit,
      provenance: DataProvenance.wearable,
      freshness: ReadingFreshness.lastSynced,
      capturedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<HealthMetricReading<int>> getBattery() async {
    final cached = _lastSnapshot.battery?.percent;
    if (cached != null) {
      return HealthMetricReading<int>(
        key: HealthMetricKeys.wearableBattery,
        displayName: 'Battery',
        value: cached,
        unit: '%',
        provenance: DataProvenance.wearable,
        freshness: ReadingFreshness.lastSynced,
        capturedAt: DateTime.now().toUtc(),
      );
    }
    try {
      if (await _native.isAvailable() && await _native.isConnected()) {
        final live = await _native.readBattery();
        if (live != null) {
          return HealthMetricReading<int>(
            key: HealthMetricKeys.wearableBattery,
            displayName: 'Battery',
            value: live.percent,
            unit: '%',
            provenance: DataProvenance.wearable,
            freshness: ReadingFreshness.live,
            capturedAt: DateTime.now().toUtc(),
          );
        }
      }
    } catch (_) {
      // Fall through to unavailable.
    }
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
      value: _lastSnapshot.heartRateBpm,
    );
  }

  @override
  Future<HealthMetricReading<int>> getHrv() async {
    return _gated(
      supported: capabilities.supportsHrv,
      key: HealthMetricKeys.hrv,
      displayName: 'HRV',
      unit: 'ms',
      value: _lastSnapshot.hrvMs,
    );
  }

  @override
  Future<HealthMetricReading<double>> getTemperature() async {
    return _gated(
      supported: capabilities.supportsTemperature,
      key: HealthMetricKeys.temperature,
      displayName: 'Temperature',
      unit: '°C',
      value: _lastSnapshot.temperatureCelsius,
    );
  }

  @override
  Future<HealthMetricReading<int>> getSpo2() async {
    return _gated(
      supported: capabilities.supportsSpo2,
      key: HealthMetricKeys.spo2,
      displayName: 'SpO₂',
      unit: '%',
      value: _lastSnapshot.spo2Percent,
    );
  }

  @override
  Future<HealthMetricReading<Duration>> getSleep() async {
    final minutes = _lastSnapshot.sleepMinutes;
    return _gated(
      supported: capabilities.supportsSleep,
      key: HealthMetricKeys.sleepDuration,
      displayName: 'Sleep',
      value: minutes == null ? null : Duration(minutes: minutes),
    );
  }

  @override
  Future<void> startWorkoutMonitoring() async {
    await _ensureNative();
    if (!capabilities.supportsWorkoutMonitoring) {
      throw const DeviceConnectionException(
        code: 'workout_unsupported',
        userMessage: 'Workout monitoring is not available on this device.',
        canRetry: false,
      );
    }
    try {
      await _native.startWorkoutMonitoring();
    } catch (error) {
      throw _mapPlatform(error);
    }
  }

  @override
  Future<void> stopWorkoutMonitoring() async {
    try {
      await _native.stopWorkoutMonitoring();
    } catch (_) {}
  }

  void dispose() {
    _connection.close();
    _info.close();
    final api = _native;
    if (api is MethodChannelQRingNativeApi) {
      api.dispose();
    }
  }
}
