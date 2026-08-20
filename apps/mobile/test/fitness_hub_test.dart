import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/analytics/conversion_analytics.dart';
import 'package:vytal_tek/domain/models/data_provenance.dart';
import 'package:vytal_tek/domain/models/ecosystem_future.dart';
import 'package:vytal_tek/domain/models/entitlements.dart';
import 'package:vytal_tek/domain/models/fitness_hub_models.dart';
import 'package:vytal_tek/domain/models/health_metric.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/fitness/ecosystem_controller.dart';
import 'package:vytal_tek/fitness/equipment_workout_builder.dart';
import 'package:vytal_tek/fitness/plan_library.dart';
import 'package:vytal_tek/fitness/progress_analytics.dart';
import 'package:vytal_tek/fitness/repositories/fitness_repositories.dart';
import 'package:vytal_tek/fitness/repositories/local_fitness_sync.dart';
import 'package:vytal_tek/fitness/today_plan_launcher.dart';
import 'package:vytal_tek/fitness/wearable_readiness.dart';
import 'package:vytal_tek/subscription/feature_access_config.dart';
import 'package:vytal_tek/subscription/monetization.dart';
import 'package:vytal_tek/subscription/product_catalog.dart';
import 'package:vytal_tek/workouts/active_workout_draft.dart';

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

    test('newPrsFromSession detects lift breakthroughs', () {
      final prior = [
        WorkoutHistoryEntry(
          id: 'old',
          name: 'Old',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 1200,
          completedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
          setLogs: const [
            WorkoutSetLog(
              exerciseName: 'Squat',
              setNumber: 1,
              setType: WorkoutSetType.working,
              completed: true,
              reps: 5,
              weightKg: 100,
            ),
          ],
        ),
      ];
      final candidate = WorkoutHistoryEntry(
        id: 'new',
        name: 'New',
        activityKind: WorkoutActivityKind.strength,
        durationSeconds: 1200,
        completedAt: DateTime.now().toUtc(),
        setLogs: const [
          WorkoutSetLog(
            exerciseName: 'Squat',
            setNumber: 1,
            setType: WorkoutSetType.working,
            completed: true,
            reps: 5,
            weightKg: 110,
          ),
        ],
      );
      final prs = ProgressAnalytics.newPrsFromSession(
        candidate: candidate,
        history: prior,
      );
      expect(prs, hasLength(1));
      expect(prs.first.exerciseName, 'Squat');
      expect(prs.first.weightKg, 110);
      expect(prs.first.previousWeightKg, 100);
    });

    test('undertrainedMuscleLabels surfaces gaps', () {
      final history = [
        WorkoutHistoryEntry(
          id: 'a',
          name: 'Push',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 1200,
          completedAt: DateTime.now().toUtc(),
          setLogs: const [
            WorkoutSetLog(
              exerciseName: 'Bench Press',
              setNumber: 1,
              setType: WorkoutSetType.working,
              completed: true,
              reps: 8,
              weightKg: 60,
            ),
          ],
        ),
      ];
      final gaps = ProgressAnalytics.undertrainedMuscleLabels(history);
      expect(gaps, contains('Back'));
      expect(gaps, isNot(contains('Chest')));
    });
  });

  group('equipment workout builder', () {
    test('builds equipment-filtered strength session', () {
      final routine = EquipmentWorkoutBuilder.build(
        minutes: 40,
        focus: 'Upper',
        equipmentLabels: const ['Dumbbells', 'Bench'],
        locationName: 'Home',
      );
      expect(routine.exercises, isNotEmpty);
      expect(routine.name, contains('40-min'));
      expect(routine.source, 'equipment');
    });

    test('makeEasier reduces sets and makeHarder adds them', () {
      final base = EquipmentWorkoutBuilder.build(
        minutes: 45,
        focus: 'Full body',
        equipmentLabels: const [],
      );
      final easier = EquipmentWorkoutBuilder.makeEasier(base);
      final harder = EquipmentWorkoutBuilder.makeHarder(base);
      expect(easier.exercises.first.sets,
          lessThanOrEqualTo(base.exercises.first.sets));
      expect(harder.exercises.first.sets,
          greaterThanOrEqualTo(base.exercises.first.sets));
    });

    test('bodyweight-only home gym rejects barbell moves', () {
      final ok = EquipmentWorkoutBuilder.exerciseMatchesEquipment(
        'Bodyweight',
        const [GymEquipmentItem.noEquipment],
      );
      final no = EquipmentWorkoutBuilder.exerciseMatchesEquipment(
        'Barbell',
        const [GymEquipmentItem.noEquipment],
      );
      expect(ok, isTrue);
      expect(no, isFalse);
    });
  });

  group('active workout draft', () {
    test('round-trips set logs for cold start restore', () async {
      final draft = ActiveWorkoutDraft(
        savedAt: DateTime.now().toUtc(),
        activityKind: WorkoutActivityKind.strength,
        elapsedSeconds: 420,
        setLogs: const [
          WorkoutSetLog(
            exerciseName: 'Goblet Squat',
            setNumber: 1,
            setType: WorkoutSetType.working,
            completed: true,
            reps: 10,
            weightKg: 20,
          ),
        ],
        routineName: 'Home session',
      );
      await ActiveWorkoutDraft.persist(draft);
      final loaded = await ActiveWorkoutDraft.load();
      expect(loaded, isNotNull);
      expect(loaded!.elapsedSeconds, 420);
      expect(loaded.setLogs, hasLength(1));
      expect(loaded.routineName, 'Home session');
      await ActiveWorkoutDraft.clear();
      expect(await ActiveWorkoutDraft.load(), isNull);
    });
  });

  group('today plan launcher labels', () {
    test('labels prefer calendar session titles', () {
      final event = FitnessCalendarEvent(
        id: 'e1',
        title: 'Full Body A',
        kind: FitnessEventKind.scheduledWorkout,
        date: DateTime.now(),
        durationMinutes: 40,
      );
      expect(
        TodayPlanLauncher.primaryLabel(
          event: event,
          summaryPending: false,
          hasActiveWorkout: false,
          isNewUser: false,
        ),
        'Start Full Body A',
      );
      expect(
        TodayPlanLauncher.primaryLabel(
          event: event,
          summaryPending: false,
          hasActiveWorkout: false,
          isNewUser: false,
          readinessScore: 25,
        ),
        'Start lighter · Full Body A',
      );
    });
  });

  group('wearable readiness', () {
    test('returns null without verified sleep or HRV', () {
      expect(
        WearableReadiness.fromVerified(
          hrv: const HealthMetricReading<int>(
            key: HealthMetricKeys.hrv,
            displayName: 'HRV',
            unit: 'ms',
            provenance: DataProvenance.wearable,
            freshness: ReadingFreshness.unavailable,
          ),
          sleep: const HealthMetricReading<Duration>(
            key: HealthMetricKeys.sleepDuration,
            displayName: 'Sleep',
            provenance: DataProvenance.wearable,
            freshness: ReadingFreshness.unavailable,
          ),
        ),
        isNull,
      );
    });

    test('scores from verified sleep + HRV only', () {
      final result = WearableReadiness.fromVerified(
        hrv: const HealthMetricReading<int>(
          key: HealthMetricKeys.hrv,
          displayName: 'HRV',
          unit: 'ms',
          value: 60,
          provenance: DataProvenance.wearable,
          freshness: ReadingFreshness.lastSynced,
        ),
        sleep: const HealthMetricReading<Duration>(
          key: HealthMetricKeys.sleepDuration,
          displayName: 'Sleep',
          value: Duration(hours: 7, minutes: 30),
          provenance: DataProvenance.wearable,
          freshness: ReadingFreshness.lastSynced,
        ),
      );
      expect(result, isNotNull);
      expect(result!.score, inInclusiveRange(1, 99));
      expect(result.message.toLowerCase(), contains('not a diagnosis'));
    });
  });

  group('local fitness sync queue', () {
    test('enqueues completed workouts for future flush', () async {
      final port = LocalQueuedFitnessSyncPort();
      await port.enqueueWorkout(
        WorkoutHistoryEntry(
          id: 'sync-1',
          name: 'Session',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 600,
          completedAt: DateTime.now().toUtc(),
        ),
      );
      expect(await port.pendingCount(), 1);
      final peek = await port.peek();
      expect(peek.first['id'], 'sync-1');
      expect(peek.first['kind'], 'workout_completed');
    });

    test('local-only flush keeps queue when endpoint missing', () async {
      final port = LocalQueuedFitnessSyncPort();
      await port.enqueueWorkout(
        WorkoutHistoryEntry(
          id: 'sync-2',
          name: 'Session',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 600,
          completedAt: DateTime.now().toUtc(),
        ),
      );
      final result = await port.flush();
      expect(result.mode, FitnessSyncFlushMode.localOnly);
      expect(result.flushedCount, 0);
      expect(result.remainingCount, 1);
      expect(await port.pendingCount(), 1);
    });

    test('remote flush clears queue on 2xx', () async {
      String? lastBody;
      final client = MockClient((request) async {
        lastBody = request.body;
        return http.Response('', 204);
      });
      final port = LocalQueuedFitnessSyncPort(
        httpClient: client,
        endpointUrl: 'https://example.test/fitness/sync',
      );
      await port.enqueueWorkout(
        WorkoutHistoryEntry(
          id: 'sync-3',
          name: 'Session',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 600,
          completedAt: DateTime.now().toUtc(),
        ),
      );
      final result = await port.flush();
      expect(result.mode, FitnessSyncFlushMode.remoteOk);
      expect(result.flushedCount, 1);
      expect(await port.pendingCount(), 0);
      expect(lastBody, contains('sync-3'));
    });

    test('remote flush failure keeps queue', () async {
      final client = MockClient(
        (_) async => http.Response('nope', 500),
      );
      final port = LocalQueuedFitnessSyncPort(
        httpClient: client,
        endpointUrl: 'https://example.test/fitness/sync',
      );
      await port.enqueueWorkout(
        WorkoutHistoryEntry(
          id: 'sync-4',
          name: 'Session',
          activityKind: WorkoutActivityKind.strength,
          durationSeconds: 600,
          completedAt: DateTime.now().toUtc(),
        ),
      );
      final result = await port.flush();
      expect(result.mode, FitnessSyncFlushMode.remoteFailed);
      expect(await port.pendingCount(), 1);
    });
  });

  group('ecosystem marketplace models', () {
    test('trainer catalog seeds three programs with fee note', () {
      final featured = TrainerMarketplaceCatalog.featured;
      expect(featured, hasLength(3));
      expect(featured.any((p) => p.advanced), isTrue);
      expect(featured.first.feeNote.toLowerCase(), contains('not charged'));
    });

    test('gym claim request persists pending status', () async {
      final controller = EcosystemController();
      await controller.restore();
      await controller.requestGymClaim(
        placeId: 'gym-1',
        businessName: 'Iron Works',
        contactEmail: 'owner@example.com',
      );
      final claim = controller.state.claimFor('gym-1');
      expect(claim, isNotNull);
      expect(claim!.claimStatus, GymClaimStatus.pending);
      expect(claim.businessName, 'Iron Works');

      await controller.markClaimApproved('gym-1');
      final approved = controller.state.claimFor('gym-1')!;
      expect(approved.claimStatus, GymClaimStatus.approved);
      expect(approved.verified, isTrue);
      expect(approved.partner, isTrue);
    });

    test('save program and express interest are idempotent', () async {
      final controller = EcosystemController();
      await controller.restore();
      await controller.saveProgram('trainer-maya-strength');
      await controller.saveProgram('trainer-maya-strength');
      await controller.expressInterest('trainer-maya-strength');
      await controller.expressInterest('trainer-maya-strength');
      expect(controller.state.savedProgramIds, ['trainer-maya-strength']);
      expect(controller.state.interestProgramIds, ['trainer-maya-strength']);
    });
  });

  group('progress photo metadata', () {
    test('entries persist angle and optional path', () {
      final photo = ProgressPhoto(
        id: 'p1',
        capturedAt: DateTime.utc(2026, 8, 20),
        localPath: '/tmp/progress.jpg',
        angle: 'side',
        weightKg: 80,
      );
      final round = ProgressPhoto.fromJson(photo.toJson());
      expect(round.angle, 'side');
      expect(round.localPath, '/tmp/progress.jpg');
      expect(round.weightKg, 80);
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
