import 'package:flutter_test/flutter_test.dart';
import 'package:vytal_tek/domain/models/fitness_hub_models.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/fitness/plan_library.dart';
import 'package:vytal_tek/fitness/progress_analytics.dart';
import 'package:vytal_tek/domain/models/entitlements.dart';
import 'package:vytal_tek/subscription/product_catalog.dart';

void main() {
  group('fitness hub domain', () {
    test('plan library covers core categories without guarantees', () {
      final plans = WorkoutPlanLibrary.all;
      expect(plans, isNotEmpty);
      expect(plans.any((p) => p.goal == PlanGoal.buildMuscle), isTrue);
      expect(plans.any((p) => p.goal == PlanGoal.homeWorkouts), isTrue);
      expect(plans.any((p) => p.advanced), isTrue);
      for (final plan in plans) {
        expect(plan.weeklyStructure, isNotEmpty);
        expect(plan.name.toLowerCase().contains('guarantee'), isFalse);
      }
    });

    test('completed history becomes calendar entry', () {
      final entry = WorkoutHistoryEntry(
        id: 'w1',
        name: 'Push Day',
        activityKind: WorkoutActivityKind.strength,
        durationSeconds: 52 * 60,
        completedAt: DateTime.utc(2026, 8, 19, 18),
        trainingVolumeKg: 4460,
        setLogs: const [
          WorkoutSetLog(
            exerciseName: 'Bench Press',
            setNumber: 1,
            setType: WorkoutSetType.working,
            completed: true,
            reps: 8,
            weightKg: 80,
          ),
        ],
      );
      final event = FitnessCalendarEvent.fromHistory(entry);
      expect(event.historyEntryId, 'w1');
      expect(event.isCompleted, isTrue);
      expect(event.title, 'Push Day');
      expect(event.durationMinutes, 52);
      expect(event.setsCompleted, 1);
    });

    test('progress analytics works without wearable fields', () {
      final history = [
        WorkoutHistoryEntry(
          id: 'a',
          name: 'A',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 1800,
          completedAt: DateTime.now().toUtc(),
          trainingVolumeKg: 2000,
          setLogs: const [
            WorkoutSetLog(
              exerciseName: 'Bench Press',
              setNumber: 1,
              setType: WorkoutSetType.working,
              completed: true,
              reps: 5,
              weightKg: 80,
            ),
          ],
        ),
        WorkoutHistoryEntry(
          id: 'b',
          name: 'B',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 2000,
          completedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
          trainingVolumeKg: 2200,
          setLogs: const [
            WorkoutSetLog(
              exerciseName: 'Bench Press',
              setNumber: 1,
              setType: WorkoutSetType.working,
              completed: true,
              reps: 5,
              weightKg: 85,
            ),
          ],
        ),
      ];
      final snap = ProgressAnalytics.build(
        history: history,
        range: ProgressRange.d30,
      );
      expect(snap.workouts, 2);
      expect(snap.volumeKg, greaterThan(0));
      expect(snap.setsCompleted, 2);
      final prs = ProgressAnalytics.newPrsFromSession(
        candidate: history.first,
        history: history,
      );
      // First session in list is older weight than second chronologically...
      // candidate a has 80, prior b has 85 → no PR
      expect(prs, isEmpty);

      final prsB = ProgressAnalytics.newPrsFromSession(
        candidate: history[1],
        history: history,
      );
      // b is older chronologically so when used as candidate vs a(80), 85 > 80
      // Actually history[1] completed earlier; prior excludes self so a remains with 80
      expect(prsB.single.exerciseName, 'Bench Press');
      expect(prsB.single.weightKg, 85);
    });
  });

  group('entitlement free product', () {
    test('free includes hub basics and not AI builder', () {
      final free = EntitlementSnapshot.freeDefaults;
      expect(free.canUse(EntitlementKeys.calendarBasic), isTrue);
      expect(free.canUse(EntitlementKeys.plansBasic), isTrue);
      expect(free.canUse(EntitlementKeys.gymsNearby), isTrue);
      expect(free.canUse(EntitlementKeys.progressBasic), isTrue);
      expect(free.canUse(EntitlementKeys.exercisesLibrary), isTrue);
      expect(free.canUse(EntitlementKeys.aiWorkoutBuilder), isFalse);
      expect(free.canUse(EntitlementKeys.plansAdvanced), isFalse);

      final catalog = SubscriptionCatalog.standard;
      expect(catalog.productForTier(SubscriptionTier.complete).displayName,
          contains('Complete'));
      expect(
        catalog.requiredPlanLabel(EntitlementKeys.aiWorkoutBuilder),
        SubscriptionTier.pro.displayLabel,
      );
    });
  });
}
