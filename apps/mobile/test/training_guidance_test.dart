import 'package:flutter_test/flutter_test.dart';
import 'package:vytal_tek/domain/models/operating_mode.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/features/today/training_guidance.dart';

void main() {
  group('TrainingGuidance', () {
    test('daily headline respects readiness bands', () {
      expect(
        TrainingGuidance.dailyHeadline(
          readinessScore: 80,
          operatingMode: OperatingMode.connected,
          hasWearableContext: true,
        ),
        'Ready to push',
      );
      expect(
        TrainingGuidance.dailyHeadline(
          readinessScore: null,
          operatingMode: OperatingMode.appOnly,
          hasWearableContext: false,
        ),
        'Train on your terms',
      );
    });

    test('counts unique training days this week', () {
      final now = DateTime.now();
      final entries = [
        WorkoutHistoryEntry(
          id: '1',
          name: 'A',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 600,
          completedAt: now.toUtc(),
        ),
        WorkoutHistoryEntry(
          id: '2',
          name: 'B',
          activityKind: WorkoutActivityKind.running,
          durationSeconds: 1200,
          completedAt: now.toUtc(),
        ),
      ];
      expect(TrainingGuidance.trainingDaysThisWeek(entries), 1);
      expect(TrainingGuidance.weekSummary(1), '1 training day this week');
    });

    test('current streak counts consecutive days ending today', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final entries = [
        WorkoutHistoryEntry(
          id: '1',
          name: 'Today',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 600,
          completedAt: today.toUtc(),
        ),
        WorkoutHistoryEntry(
          id: '2',
          name: 'Yesterday',
          activityKind: WorkoutActivityKind.walking,
          durationSeconds: 900,
          completedAt: yesterday.toUtc(),
        ),
      ];
      expect(TrainingGuidance.currentStreakDays(entries), 2);
    });

    test('week scorecard aggregates minutes and sessions', () {
      final now = DateTime.now();
      final entries = [
        WorkoutHistoryEntry(
          id: '1',
          name: 'A',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 1800,
          completedAt: now.toUtc(),
        ),
      ];
      final card = TrainingGuidance.weekScorecard(entries);
      expect(card.sessions, 1);
      expect(card.totalMinutes, 30);
      expect(card.suggestion, isNotEmpty);
    });

    test('personal records detect longest session', () {
      final prior = [
        WorkoutHistoryEntry(
          id: 'old',
          name: 'Old',
          activityKind: WorkoutActivityKind.walking,
          durationSeconds: 600,
          completedAt: DateTime.now().toUtc(),
        ),
      ];
      final candidate = WorkoutHistoryEntry(
        id: 'new',
        name: 'New',
        activityKind: WorkoutActivityKind.walking,
        durationSeconds: 1200,
        completedAt: DateTime.now().toUtc(),
      );
      final records = TrainingGuidance.personalRecordsBroken(
        candidate: candidate,
        history: prior,
      );
      expect(records.any((r) => r.label == 'Longest session'), isTrue);
    });
  });
}
