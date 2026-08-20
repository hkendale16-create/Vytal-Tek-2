import '../../domain/models/operating_mode.dart';
import '../../domain/models/workout_models.dart';

/// Plain-language training guidance for Today and Workouts — no invented scores.
abstract final class TrainingGuidance {
  static String dailyHeadline({
    required int? readinessScore,
    required OperatingMode operatingMode,
    required bool hasWearableContext,
  }) {
    if (operatingMode == OperatingMode.appOnly && !hasWearableContext) {
      return 'Train on your terms';
    }
    if (readinessScore == null) {
      return 'Start with how you feel';
    }
    if (readinessScore >= 75) return 'Ready to push';
    if (readinessScore >= 50) return 'Steady training day';
    if (readinessScore >= 30) return 'Go lighter today';
    return 'Prioritize recovery';
  }

  static String workoutHubHint(int? readinessScore) {
    if (readinessScore == null) {
      return 'Quick Start works in App-Only mode. Connect a ring for live heart rate.';
    }
    if (readinessScore >= 75) {
      return 'Readiness looks strong — good day for strength or intervals.';
    }
    if (readinessScore >= 50) {
      return 'Balanced readiness — moderate effort fits today.';
    }
    if (readinessScore >= 30) {
      return 'Recovery is moderate — favor technique, mobility, or light cardio.';
    }
    return 'Recovery is low — keep effort easy or focus on rest.';
  }

  static String postWorkoutTip(int? readinessScore) {
    if (readinessScore == null) {
      return 'Session logged. Hydrate and note how you felt.';
    }
    if (readinessScore >= 60) {
      return 'Solid work today. A lighter session tomorrow may help you absorb the load.';
    }
    return 'You showed up — prioritize sleep and easy movement tomorrow.';
  }

  static int trainingDaysThisWeek(List<WorkoutHistoryEntry> entries) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final days = <int>{};
    for (final entry in entries) {
      final local = entry.completedAt.toLocal();
      if (local.isBefore(startOfWeek)) continue;
      days.add(DateTime(local.year, local.month, local.day).millisecondsSinceEpoch);
    }
    return days.length;
  }

  static String weekSummary(int trainingDays) {
    if (trainingDays == 0) return 'No sessions yet this week';
    if (trainingDays == 1) return '1 training day this week';
    return '$trainingDays training days this week';
  }
}
