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
  });
}
