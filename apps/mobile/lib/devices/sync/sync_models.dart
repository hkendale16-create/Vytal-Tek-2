import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';

/// One buffered sample awaiting local persistence / later backend batch sync.
class BufferedHealthSample {
  const BufferedHealthSample({
    required this.id,
    required this.deviceId,
    required this.metricKey,
    required this.capturedAt,
    required this.provenance,
    required this.payload,
    this.sessionId,
  });

  final String id;
  final String deviceId;
  final String metricKey;
  final DateTime capturedAt;
  final DataProvenance provenance;
  final Map<String, dynamic> payload;
  final String? sessionId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceId': deviceId,
        'metricKey': metricKey,
        'capturedAt': capturedAt.toIso8601String(),
        'provenance': provenance.name,
        'payload': payload,
        'sessionId': sessionId,
      };

  factory BufferedHealthSample.fromJson(Map<String, dynamic> json) {
    return BufferedHealthSample(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      metricKey: json['metricKey'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      provenance: DataProvenance.values.firstWhere(
        (e) => e.name == json['provenance'],
        orElse: () => DataProvenance.wearable,
      ),
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      sessionId: json['sessionId'] as String?,
    );
  }
}

enum SyncStatus {
  idle,
  syncing,
  success,
  failed,
  offlineQueued,
}

class SyncResult {
  const SyncResult({
    required this.status,
    required this.finishedAt,
    this.samplesAccepted = 0,
    this.samplesDeduped = 0,
    this.message,
    this.errorCode,
  });

  final SyncStatus status;
  final DateTime finishedAt;
  final int samplesAccepted;
  final int samplesDeduped;
  final String? message;
  final String? errorCode;

  bool get ok =>
      status == SyncStatus.success || status == SyncStatus.offlineQueued;
}

/// In-memory + prefs-backed local buffer. Batches locally; does not flood a backend.
class HealthSampleBuffer {
  HealthSampleBuffer({List<BufferedHealthSample>? seed})
      : _samples = List.of(seed ?? const []);

  static const maxSamples = 2000;

  final List<BufferedHealthSample> _samples;
  final Set<String> _seenKeys = {};

  List<BufferedHealthSample> get samples => List.unmodifiable(_samples);

  int get length => _samples.length;

  /// Dedup key: device + metric + timestamp (+ session).
  String _dedupeKey(BufferedHealthSample sample) =>
      '${sample.deviceId}|${sample.metricKey}|${sample.capturedAt.toIso8601String()}|${sample.sessionId ?? ''}';

  int enqueue(BufferedHealthSample sample) {
    final key = _dedupeKey(sample);
    if (_seenKeys.contains(key)) return 0;
    _seenKeys.add(key);
    _samples.add(sample);
    if (_samples.length > maxSamples) {
      final overflow = _samples.length - maxSamples;
      _samples.removeRange(0, overflow);
    }
    return 1;
  }

  int enqueueAll(Iterable<BufferedHealthSample> samples) {
    var accepted = 0;
    for (final sample in samples) {
      accepted += enqueue(sample);
    }
    return accepted;
  }

  List<BufferedHealthSample> takeBatch({int limit = 100}) {
    if (_samples.isEmpty) return const [];
    final end = _samples.length < limit ? _samples.length : limit;
    final batch = _samples.sublist(0, end);
    _samples.removeRange(0, end);
    for (final sample in batch) {
      _seenKeys.remove(_dedupeKey(sample));
    }
    return batch;
  }

  Map<String, dynamic> toJson() => {
        'samples': _samples.map((s) => s.toJson()).toList(),
      };

  factory HealthSampleBuffer.fromJson(Map<String, dynamic>? json) {
    if (json == null) return HealthSampleBuffer();
    final raw = json['samples'] as List? ?? const [];
    final samples = raw
        .whereType<Map>()
        .map((e) => BufferedHealthSample.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final buffer = HealthSampleBuffer(seed: samples);
    for (final sample in samples) {
      buffer._seenKeys.add(buffer._dedupeKey(sample));
    }
    return buffer;
  }
}

/// Summary record after a sync pass — used for "Last synced" UI (never as Live).
class DeviceSyncSummary {
  const DeviceSyncSummary({
    required this.deviceId,
    required this.syncedAt,
    required this.result,
    this.battery,
  });

  final String deviceId;
  final DateTime syncedAt;
  final SyncResult result;
  final HealthMetricReading<int>? battery;
}
