import '../domain/models/fitness_hub_models.dart';
import '../domain/models/workout_models.dart';
import '../features/today/training_guidance.dart';

enum ProgressRange { d7, d30, m3, m6, y1 }

extension ProgressRangeX on ProgressRange {
  String get label => switch (this) {
        ProgressRange.d7 => '7D',
        ProgressRange.d30 => '30D',
        ProgressRange.m3 => '3M',
        ProgressRange.m6 => '6M',
        ProgressRange.y1 => '1Y',
      };

  Duration get duration => switch (this) {
        ProgressRange.d7 => const Duration(days: 7),
        ProgressRange.d30 => const Duration(days: 30),
        ProgressRange.m3 => const Duration(days: 90),
        ProgressRange.m6 => const Duration(days: 180),
        ProgressRange.y1 => const Duration(days: 365),
      };
}

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.workouts,
    required this.trainingSeconds,
    required this.volumeKg,
    required this.setsCompleted,
    required this.workoutsPerWeek,
    required this.strengthDeltas,
    required this.sessionRecords,
    required this.streakDays,
  });

  final int workouts;
  final int trainingSeconds;
  final double volumeKg;
  final int setsCompleted;
  final double workoutsPerWeek;
  final List<StrengthPersonalRecord> strengthDeltas;
  final List<PersonalRecord> sessionRecords;
  final int streakDays;

  String get trainingTimeLabel {
    final h = trainingSeconds ~/ 3600;
    final m = (trainingSeconds % 3600) ~/ 60;
    if (h <= 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String get volumeLabel {
    final lb = volumeKg * 2.20462;
    if (lb >= 1000) return '${(lb / 1000).toStringAsFixed(0)}K lb';
    return '${lb.round()} lb';
  }
}

/// Device-free progress from workout history — no wearable required.
abstract final class ProgressAnalytics {
  static ProgressSnapshot build({
    required List<WorkoutHistoryEntry> history,
    ProgressRange range = ProgressRange.d30,
    DateTime? now,
  }) {
    final anchor = now ?? DateTime.now();
    final start = anchor.subtract(range.duration);
    final window = history
        .where((e) => e.completedAt.toLocal().isAfter(start))
        .toList();

    final workouts = window.length;
    final seconds =
        window.fold<int>(0, (sum, e) => sum + e.durationSeconds);
    final volume =
        window.fold<double>(0, (sum, e) => sum + (e.trainingVolumeKg ?? 0));
    final sets = window.fold<int>(
      0,
      (sum, e) => sum + e.setLogs.where((s) => s.completed).length,
    );
    final weeks = range.duration.inDays / 7.0;
    final perWeek = weeks <= 0 ? 0.0 : workouts / weeks;

    return ProgressSnapshot(
      workouts: workouts,
      trainingSeconds: seconds,
      volumeKg: volume,
      setsCompleted: sets,
      workoutsPerWeek: perWeek,
      strengthDeltas: strengthProgress(history),
      sessionRecords: _bestSessionRecords(history),
      streakDays: TrainingGuidance.currentStreakDays(history),
    );
  }

  static List<StrengthPersonalRecord> strengthProgress(
    List<WorkoutHistoryEntry> history,
  ) {
    final best = <String, StrengthPersonalRecord>{};
    final ordered = [...history]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    for (final entry in ordered) {
      for (final log in entry.setLogs) {
        if (!log.completed || log.weightKg == null) continue;
        final name = log.exerciseName;
        final prev = best[name];
        if (prev == null || log.weightKg! > prev.weightKg) {
          best[name] = StrengthPersonalRecord(
            exerciseName: name,
            weightKg: log.weightKg!,
            achievedAt: entry.completedAt,
            previousWeightKg: prev?.weightKg,
            reps: log.reps,
          );
        }
      }
    }
    final list = best.values.toList()
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
    return list;
  }

  /// Detect new lift PRs vs prior history for celebration UI.
  static List<StrengthPersonalRecord> newPrsFromSession({
    required WorkoutHistoryEntry candidate,
    required List<WorkoutHistoryEntry> history,
  }) {
    final prior = history.where((e) => e.id != candidate.id).toList();
    final priorBest = <String, double>{};
    for (final entry in prior) {
      for (final log in entry.setLogs) {
        if (!log.completed || log.weightKg == null) continue;
        final cur = priorBest[log.exerciseName] ?? 0;
        if (log.weightKg! > cur) priorBest[log.exerciseName] = log.weightKg!;
      }
    }
    final found = <StrengthPersonalRecord>[];
    final sessionBest = <String, WorkoutSetLog>{};
    for (final log in candidate.setLogs) {
      if (!log.completed || log.weightKg == null) continue;
      final existing = sessionBest[log.exerciseName];
      if (existing == null ||
          (existing.weightKg ?? 0) < (log.weightKg ?? 0)) {
        sessionBest[log.exerciseName] = log;
      }
    }
    for (final entry in sessionBest.entries) {
      final prev = priorBest[entry.key];
      final weight = entry.value.weightKg!;
      if (prev == null || weight > prev) {
        found.add(
          StrengthPersonalRecord(
            exerciseName: entry.key,
            weightKg: weight,
            achievedAt: candidate.completedAt,
            previousWeightKg: prev,
            reps: entry.value.reps,
          ),
        );
      }
    }
    return found;
  }

  static List<PersonalRecord> _bestSessionRecords(
    List<WorkoutHistoryEntry> history,
  ) {
    if (history.isEmpty) return const [];
    final best = history.reduce(
      (a, b) => (a.trainingVolumeKg ?? 0) >= (b.trainingVolumeKg ?? 0) ? a : b,
    );
    return TrainingGuidance.personalRecordsBroken(
      candidate: best,
      history: history,
    );
  }
}
