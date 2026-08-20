import '../../domain/models/health_metric.dart';

/// Conservative readiness from **verified** wearable metrics only.
///
/// Never invents missing vitals. Returns null when inputs are insufficient.
/// Labeled as an informational estimate — not a medical assessment.
abstract final class WearableReadiness {
  static ({int score, String message})? fromVerified({
    required HealthMetricReading<int> hrv,
    required HealthMetricReading<Duration> sleep,
    HealthMetricReading<int>? heartRate,
  }) {
    var parts = 0;
    var total = 0.0;

    if (hrv.hasValue && hrv.value != null) {
      parts += 1;
      // Coarse band only — not a clinical HRV interpretation.
      final v = hrv.value!;
      final band = v >= 70
          ? 90.0
          : v >= 45
              ? 70.0
              : v >= 25
                  ? 50.0
                  : 35.0;
      total += band;
    }

    if (sleep.hasValue && sleep.value != null) {
      parts += 1;
      final minutes = sleep.value!.inMinutes;
      final band = minutes >= 450
          ? 90.0
          : minutes >= 360
              ? 72.0
              : minutes >= 300
                  ? 55.0
                  : 40.0;
      total += band;
    }

    if (parts == 0) return null;

    // Resting HR is optional softener when unusually high relative to nothing —
    // we only nudge slightly if HR is present and elevated (>90), never invent.
    var score = (total / parts).round().clamp(1, 99);
    if (heartRate?.hasValue == true && (heartRate!.value ?? 0) >= 95) {
      score = (score - 8).clamp(1, 99);
    }

    final message = parts == 2
        ? 'Informational readiness from verified sleep + HRV — not a diagnosis.'
        : 'Informational readiness from available verified metrics — not a diagnosis.';
    return (score: score, message: message);
  }
}
