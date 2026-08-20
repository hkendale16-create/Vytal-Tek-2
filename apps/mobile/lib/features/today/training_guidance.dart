import '../../domain/models/operating_mode.dart';
import '../../domain/models/workout_models.dart';

/// Plain-language training guidance — no invented vitals or fake scores.
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

  static DateTime _dayKey(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime startOfWeek([DateTime? now]) {
    final day = now ?? DateTime.now();
    final local = DateTime(day.year, day.month, day.day);
    return local.subtract(Duration(days: local.weekday - 1));
  }

  static int trainingDaysThisWeek(List<WorkoutHistoryEntry> entries) {
    final start = startOfWeek();
    final days = <int>{};
    for (final entry in entries) {
      final day = _dayKey(entry.completedAt);
      if (day.isBefore(start)) continue;
      days.add(day.millisecondsSinceEpoch);
    }
    return days.length;
  }

  static String weekSummary(int trainingDays) {
    if (trainingDays == 0) return 'No sessions yet this week';
    if (trainingDays == 1) return '1 training day this week';
    return '$trainingDays training days this week';
  }

  /// Consecutive calendar days with ≥1 session, ending today or yesterday.
  static int currentStreakDays(List<WorkoutHistoryEntry> entries) {
    if (entries.isEmpty) return 0;
    final days = entries.map((e) => _dayKey(e.completedAt)).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final today = _dayKey(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    if (days.first != today && days.first != yesterday) return 0;
    var streak = 1;
    var cursor = days.first;
    for (var i = 1; i < days.length; i++) {
      final expected = cursor.subtract(const Duration(days: 1));
      if (days[i] != expected) break;
      streak += 1;
      cursor = days[i];
    }
    return streak;
  }

  static WeeklyScorecard weekScorecard(List<WorkoutHistoryEntry> entries) {
    final start = startOfWeek();
    final week = entries
        .where((e) => !_dayKey(e.completedAt).isBefore(start))
        .toList(growable: false);
    final sessions = week.length;
    final minutes =
        week.fold<int>(0, (sum, e) => sum + (e.durationSeconds ~/ 60));
    final days = trainingDaysThisWeek(entries);
    final streak = currentStreakDays(entries);
    final isMonday = DateTime.now().weekday == DateTime.monday;
    return WeeklyScorecard(
      sessions: sessions,
      totalMinutes: minutes,
      trainingDays: days,
      streakDays: streak,
      isMondayReview: isMonday,
      suggestion: weekSuggestion(
        sessions: sessions,
        trainingDays: days,
        streakDays: streak,
      ),
    );
  }

  static String weekSuggestion({
    required int sessions,
    required int trainingDays,
    required int streakDays,
  }) {
    if (sessions == 0) {
      return 'One Quick Start today starts your week.';
    }
    if (trainingDays >= 4) {
      return 'Strong consistency — protect recovery on rest days.';
    }
    if (streakDays >= 3) {
      return 'Streak is alive — keep the next session short if needed.';
    }
    if (sessions == 1) {
      return 'Nice start. Another session this week locks the habit.';
    }
    return 'Stay consistent — even 20 minutes counts.';
  }

  /// Personal records broken by [candidate] vs prior history (excludes itself by id).
  static List<PersonalRecord> personalRecordsBroken({
    required WorkoutHistoryEntry candidate,
    required List<WorkoutHistoryEntry> history,
  }) {
    final prior = history.where((e) => e.id != candidate.id).toList();
    final records = <PersonalRecord>[];

    final priorMaxDuration = prior.fold<int>(
      0,
      (max, e) => e.durationSeconds > max ? e.durationSeconds : max,
    );
    if (candidate.durationSeconds > 0 &&
        candidate.durationSeconds > priorMaxDuration) {
      records.add(
        PersonalRecord(
          label: prior.isEmpty ? 'First session logged' : 'Longest session',
          detail: _formatMinutes(candidate.durationSeconds),
        ),
      );
    }

    final volume = candidate.trainingVolumeKg ?? 0;
    final priorMaxVolume = prior.fold<double>(
      0,
      (max, e) => (e.trainingVolumeKg ?? 0) > max ? (e.trainingVolumeKg ?? 0) : max,
    );
    if (volume > 0 && volume > priorMaxVolume) {
      records.add(
        PersonalRecord(
          label: prior.isEmpty ? 'First strength volume' : 'Highest volume',
          detail: '${volume.round()} kg',
        ),
      );
    }

    final distance = candidate.distanceMeters ?? 0;
    final priorMaxDistance = prior.fold<double>(
      0,
      (max, e) => (e.distanceMeters ?? 0) > max ? (e.distanceMeters ?? 0) : max,
    );
    if (distance > 0 && distance > priorMaxDistance) {
      records.add(
        PersonalRecord(
          label: prior.isEmpty ? 'First distance logged' : 'Farthest distance',
          detail: '${(distance / 1000).toStringAsFixed(2)} km',
        ),
      );
    }

    final setCount = candidate.setLogs.where((l) => l.completed).length;
    final priorMaxSets = prior.fold<int>(
      0,
      (max, e) {
        final count = e.setLogs.where((l) => l.completed).length;
        return count > max ? count : max;
      },
    );
    if (setCount > 0 && setCount > priorMaxSets) {
      records.add(
        PersonalRecord(
          label: prior.isEmpty ? 'First sets logged' : 'Most sets in a session',
          detail: '$setCount sets',
        ),
      );
    }

    return records;
  }

  static String _formatMinutes(int seconds) {
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    if (minutes == 0) return '${seconds}s';
    if (rem == 0) return '${minutes}m';
    return '${minutes}m ${rem}s';
  }
}

class WeeklyScorecard {
  const WeeklyScorecard({
    required this.sessions,
    required this.totalMinutes,
    required this.trainingDays,
    required this.streakDays,
    required this.isMondayReview,
    required this.suggestion,
  });

  final int sessions;
  final int totalMinutes;
  final int trainingDays;
  final int streakDays;
  final bool isMondayReview;
  final String suggestion;
}

class PersonalRecord {
  const PersonalRecord({required this.label, required this.detail});

  final String label;
  final String detail;
}
