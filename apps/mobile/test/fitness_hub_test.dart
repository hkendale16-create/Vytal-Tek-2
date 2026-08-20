import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/analytics/conversion_analytics.dart';
import 'package:vytal_tek/domain/models/entitlements.dart';
import 'package:vytal_tek/domain/models/fitness_hub_models.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/fitness/plan_library.dart';
import 'package:vytal_tek/fitness/progress_analytics.dart';
import 'package:vytal_tek/subscription/feature_access_config.dart';
import 'package:vytal_tek/subscription/monetization.dart';
import 'package:vytal_tek/subscription/product_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('monetization experience states', () {
    test('free without device', () {
      expect(
        MonetizationFacade.resolve(
          snapshot: EntitlementSnapshot.freeDefaults,
          devicePaired: false,
        ),
        VytalExperienceState.free,
      );
    });

    test('device owner keeps free software', () {
      expect(
        MonetizationFacade.resolve(
          snapshot: EntitlementSnapshot.freeDefaults,
          devicePaired: true,
        ),
        VytalExperienceState.deviceOwner,
      );
    });

    test('pro + device becomes proDevice', () {
      final pro = EntitlementSnapshot.forTier(
        SubscriptionTier.pro,
        enabled: SubscriptionCatalog.standard
            .productForTier(SubscriptionTier.pro)
            .entitlements,
        verificationSource: EntitlementVerificationSource.serverVerified,
      );
      expect(
        MonetizationFacade.resolve(snapshot: pro, devicePaired: true),
        VytalExperienceState.proDevice,
      );
      expect(
        MonetizationFacade.resolve(snapshot: pro, devicePaired: false),
        VytalExperienceState.pro,
      );
    });

    test('core device features are never subscription keys', () {
      expect(
        DeviceExperienceFeatures.isCoreDeviceFeature(
          DeviceExperienceFeatures.batteryManagement,
        ),
        isTrue,
      );
      expect(
        DeviceExperienceFeatures.isCoreDeviceFeature(
          EntitlementKeys.aiWorkoutBuilder,
        ),
        isFalse,
      );
    });
  });

  group('plan library monetization', () {
    test('free starters are available without PRO', () {
      final starters = WorkoutPlanLibrary.freeStarters;
      expect(starters.length, greaterThanOrEqualTo(5));
      expect(
        starters.map((p) => p.name),
        containsAll([
          'Beginner Strength',
          '3-Day Full Body',
          'Home Starter',
          'Beginner Cardio',
          'Basic Calisthenics',
        ]),
      );
      for (final plan in starters) {
        expect(WorkoutPlanLibrary.requiresPro(plan), isFalse);
      }
    });

    test('premium plans stay visible and marked advanced', () {
      final pro = WorkoutPlanLibrary.proPlans;
      expect(pro, isNotEmpty);
      expect(pro.any((p) => p.name.contains('Push / Pull')), isTrue);
      for (final plan in pro) {
        expect(plan.advanced, isTrue);
        expect(WorkoutPlanLibrary.requiresPro(plan), isTrue);
      }
    });
  });

  group('feature access config', () {
    test('bundled defaults keep gyms free', () {
      final config = FeatureAccessConfig.bundled;
      expect(config.isFeatureEnabled(EntitlementKeys.gymsNearby), isTrue);
      expect(config.aiCoachDailyLimitFree, greaterThan(0));
    });
  });

  group('conversion analytics privacy', () {
    test('allows funnel events and strips blocked biometric keys', () async {
      final analytics = LocalConversionAnalytics();
      await analytics.track(
        ConversionEvents.workoutCompleted,
        properties: {
          'activity': 'strength',
          'heartRate': 140, // must be dropped
          'duration_seconds': 1800,
        },
      );
      await analytics.track('not_an_allowed_event');
      final drained = await analytics.drain();
      expect(drained.length, 1);
      expect(drained.first['event'], ConversionEvents.workoutCompleted);
      final props = Map<String, dynamic>.from(
        drained.first['properties'] as Map,
      );
      expect(props.containsKey('heartRate'), isFalse);
      expect(props['duration_seconds'], 1800);
    });
  });

  group('progress still device-free', () {
    test('analytics work without wearable fields', () {
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
      ];
      final snap = ProgressAnalytics.build(
        history: history,
        range: ProgressRange.d30,
      );
      expect(snap.workouts, 1);
    });
  });

  group('entitlement free product', () {
    test('free includes hub basics and not AI builder', () {
      final free = EntitlementSnapshot.freeDefaults;
      expect(free.canUse(EntitlementKeys.calendarBasic), isTrue);
      expect(free.canUse(EntitlementKeys.plansBasic), isTrue);
      expect(free.canUse(EntitlementKeys.gymsNearby), isTrue);
      expect(free.canUse(EntitlementKeys.progressBasic), isTrue);
      expect(free.canUse(EntitlementKeys.aiWorkoutBuilder), isFalse);
      expect(free.canUse(EntitlementKeys.plansAdvanced), isFalse);
    });
  });
}
