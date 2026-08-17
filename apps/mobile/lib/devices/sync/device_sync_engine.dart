import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../devices/connection/device_connection_exception.dart';
import '../../domain/devices/wearable_device.dart';
import 'sync_models.dart';

const _bufferKey = 'vytal.sync.buffer.v1';
const _lastSyncKey = 'vytal.sync.last.v1';

class SyncRepository {
  Future<HealthSampleBuffer> loadBuffer() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bufferKey);
    if (raw == null) return HealthSampleBuffer();
    try {
      return HealthSampleBuffer.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return HealthSampleBuffer();
    }
  }

  Future<void> saveBuffer(HealthSampleBuffer buffer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bufferKey, jsonEncode(buffer.toJson()));
  }

  Future<Map<String, DateTime>> loadLastSyncByDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (key, value) => MapEntry(key, DateTime.parse(value as String)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveLastSync(String deviceId, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadLastSyncByDevice();
    current[deviceId] = at;
    await prefs.setString(
      _lastSyncKey,
      jsonEncode(
        current.map((key, value) => MapEntry(key, value.toIso8601String())),
      ),
    );
  }
}

/// Runs adapter.sync(), buffers samples locally, records last-sync timestamps.
class DeviceSyncEngine {
  DeviceSyncEngine({
    SyncRepository? repository,
  }) : _repository = repository ?? SyncRepository();

  final SyncRepository _repository;

  Future<SyncResult> syncDevice(
    WearableDevice device, {
    required String deviceId,
  }) async {
    final buffer = await _repository.loadBuffer();
    try {
      await device.sync();
      final now = DateTime.now().toUtc();
      await _repository.saveLastSync(deviceId, now);
      await _repository.saveBuffer(buffer);
      return SyncResult(
        status: SyncStatus.success,
        finishedAt: now,
        samplesAccepted: 0,
        message: 'Device sync completed. Samples will batch when available.',
      );
    } on DeviceConnectionException catch (error) {
      return SyncResult(
        status: SyncStatus.failed,
        finishedAt: DateTime.now().toUtc(),
        message: error.userMessage,
        errorCode: error.code,
      );
    } catch (error) {
      return SyncResult(
        status: SyncStatus.failed,
        finishedAt: DateTime.now().toUtc(),
        message:
            'We couldn’t finish syncing. Keep the device nearby and try again.',
        errorCode: error.runtimeType.toString(),
      );
    }
  }

  Future<int> enqueueSamples(Iterable<BufferedHealthSample> samples) async {
    final buffer = await _repository.loadBuffer();
    final accepted = buffer.enqueueAll(samples);
    await _repository.saveBuffer(buffer);
    return accepted;
  }
}
