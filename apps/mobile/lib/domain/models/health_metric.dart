import 'data_provenance.dart';

/// Freshness / connection presentation for readings.
enum ReadingFreshness {
  live,
  updating,
  lastSynced,
  disconnected,
  unavailable,
  notSupported,
}

extension ReadingFreshnessX on ReadingFreshness {
  String get label => switch (this) {
        ReadingFreshness.live => 'Live',
        ReadingFreshness.updating => 'Updating',
        ReadingFreshness.lastSynced => 'Last synced',
        ReadingFreshness.disconnected => 'Disconnected',
        ReadingFreshness.unavailable => 'No recent reading',
        ReadingFreshness.notSupported => 'Not supported by this device',
      };
}

/// A typed health metric container. Null [value] means missing — never invent.
class HealthMetricReading<T> {
  const HealthMetricReading({
    required this.key,
    required this.displayName,
    required this.provenance,
    required this.freshness,
    this.value,
    this.unit,
    this.capturedAt,
    this.statusLabel,
  });

  final String key;
  final String displayName;
  final T? value;
  final String? unit;
  final DataProvenance provenance;
  final ReadingFreshness freshness;
  final DateTime? capturedAt;
  final String? statusLabel;

  bool get hasValue => value != null;

  HealthMetricReading<T> copyWith({
    T? value,
    String? unit,
    DataProvenance? provenance,
    ReadingFreshness? freshness,
    DateTime? capturedAt,
    String? statusLabel,
  }) {
    return HealthMetricReading<T>(
      key: key,
      displayName: displayName,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      provenance: provenance ?? this.provenance,
      freshness: freshness ?? this.freshness,
      capturedAt: capturedAt ?? this.capturedAt,
      statusLabel: statusLabel ?? this.statusLabel,
    );
  }
}

/// Canonical metric keys used across UI and AI context builders.
abstract final class HealthMetricKeys {
  static const heartRate = 'heart_rate';
  static const restingHeartRate = 'resting_heart_rate';
  static const hrv = 'hrv';
  static const spo2 = 'spo2';
  static const temperature = 'temperature';
  static const respiratoryRate = 'respiratory_rate';
  static const steps = 'steps';
  static const calories = 'calories';
  static const distance = 'distance';
  static const sleepScore = 'sleep_score';
  static const sleepDuration = 'sleep_duration';
  static const recovery = 'recovery';
  static const readiness = 'readiness';
  static const stress = 'stress';
  static const energy = 'energy';
  static const trainingLoad = 'training_load';
  static const wearableBattery = 'wearable_battery';
}
