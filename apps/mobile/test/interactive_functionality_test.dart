import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/core/permissions/permission_catalog.dart';
import 'package:vytal_tek/core/theme/vytal_colors.dart';
import 'package:vytal_tek/devices/connection/bluetooth_readiness.dart';
import 'package:vytal_tek/devices/connection/ble_signal.dart';
import 'package:vytal_tek/devices/connection/device_connection_exception.dart';
import 'package:vytal_tek/domain/devices/device_connection_state.dart';
import 'package:vytal_tek/devices/connection/pairing_platform.dart';
import 'package:vytal_tek/domain/models/notes_models.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/features/ai/coach_vital_engine.dart';
import 'package:vytal_tek/notes/notes_controller.dart';
import 'package:vytal_tek/state/app_session_controller.dart';
import 'package:vytal_tek/workouts/exercise_library.dart';
import 'package:vytal_tek/workouts/workout_controllers.dart';
import 'package:vytal_tek/workouts/workout_gps.dart';
import 'package:vytal_tek/workouts/workout_metrics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Pairing platform', () {
    test('mobile builds do not use the web-only pairing copy', () {
      if (PairingPlatform.blePairingSupported) {
        expect(
          PairingPlatform.limitationMessage(demoModeEnabled: false),
          isEmpty,
        );
      } else {
        final message =
            PairingPlatform.limitationMessage(demoModeEnabled: false);
        expect(message, isNotEmpty);
        if (kIsWeb) {
          expect(message.toLowerCase(), contains('web'));
        }
        if (PairingPlatform.isDesktop) {
          expect(message.toLowerCase(), contains('desktop'));
        }
      }
    });

    test('bluetooth-off and scan-timeout are distinct from no-devices', () {
      expect(DeviceConnectionException.bluetoothOff.code, 'bluetooth_off');
      expect(DeviceConnectionException.scanTimeout.code, 'scan_timeout');
      const off = BluetoothReadinessResult(
        status: BluetoothReadiness.bluetoothOff,
      );
      expect(off.asException?.code, 'bluetooth_off');
    });
  });

  group('Permissions catalog', () {
    test('status labels match the permissions center copy', () {
      expect(VytalPermissionStatus.granted.label, 'Enabled');
      expect(VytalPermissionStatus.denied.label, 'Denied');
      expect(
        VytalPermissionStatus.permanentlyDenied.label,
        'Permanently Denied',
      );
      expect(VytalPermissionStatus.notApplicable.label, 'Not Required');
      expect(VytalPermissionStatus.unsupported.label, 'Unsupported');
    });
  });

  group('Theme glow', () {
    test('dark glow token stays restrained', () {
      const glow = Color(0xFF00E0D0);
      expect(glow.withValues(alpha: 0.05).a, lessThan(0.1));
    });

    test('dark canvas is true black, not navy-teal', () {
      expect(VytalColors.darkCanvas, const Color(0xFF050505));
      expect(VytalColors.darkSurface, const Color(0xFF111111));
      expect(VytalColors.green, isNot(VytalColors.darkCanvas));
    });
  });

  group('Workouts', () {
    test('running start/pause/stop preserves summary', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = container.read(workoutSessionProvider.notifier);
      session.startActivity(WorkoutActivityKind.running);
      expect(container.read(workoutSessionProvider).running, isTrue);
      expect(
        container.read(workoutSessionProvider).playMode,
        WorkoutPlayMode.activity,
      );
      session.pause();
      expect(container.read(workoutSessionProvider).running, isFalse);
      session.resume();
      expect(container.read(workoutSessionProvider).running, isTrue);
      session.stopAndSummarize();
      expect(container.read(workoutSessionProvider).summaryPending, isTrue);
      expect(container.read(workoutSessionProvider).phases, isNotEmpty);
      session.stop();
    });

    test('HIIT starts with interval phases', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(workoutSessionProvider.notifier)
          .startActivity(WorkoutActivityKind.hiit);
      final state = container.read(workoutSessionProvider);
      expect(state.phases.length, greaterThan(1));
      expect(state.currentPhase?.kind, WorkoutTimerKind.interval);
      expect(
        WorkoutMetricCatalog.forKind(WorkoutActivityKind.hiit),
        contains(WorkoutMetricId.round),
      );
    });

    test('strength draft can add exercises and complete a set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(workoutSessionProvider.notifier);
      n.startActivity(WorkoutActivityKind.strength);
      expect(container.read(workoutSessionProvider).phases, isEmpty);
      n.addExerciseToSession(
        ExerciseLibrary.byName('Bench Press')!.toExercise(weightKg: 61),
      );
      final after = container.read(workoutSessionProvider);
      expect(after.phases, isNotEmpty);
      expect(after.currentPhase?.muscleGroup, MuscleGroup.chest);
      n.completeSet();
      expect(
        container.read(workoutSessionProvider).currentPhase?.kind,
        WorkoutTimerKind.rest,
      );
    });

    test('reset returns elapsed time to zero', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(workoutSessionProvider.notifier);
      n.startActivity(WorkoutActivityKind.walking);
      n.resetSession();
      final state = container.read(workoutSessionProvider);
      expect(state.elapsedSeconds(), 0);
      expect(state.running, isFalse);
      expect(state.activityKind, WorkoutActivityKind.walking);
    });

    test('exercise library covers required muscle groups', () {
      for (final group in MuscleGroup.values) {
        expect(ExerciseLibrary.forGroup(group), isNotEmpty, reason: group.label);
      }
    });

    test('GPS tracker accumulates distance and pace from samples', () {
      final tracker = WorkoutGpsTracker();
      final t0 = DateTime.utc(2026, 8, 17, 14);
      tracker.add(
        GpsFix(latitude: 37.7749, longitude: -122.4194, at: t0),
      );
      tracker.add(
        GpsFix(
          latitude: 37.7753,
          longitude: -122.4194,
          at: t0.add(const Duration(seconds: 12)),
        ),
      );
      expect(tracker.distanceMeters, greaterThan(30));
      expect(tracker.normalizedRoute, isNotEmpty);
      expect(formatPace(tracker.distanceMeters, 12), isNotNull);
    });

    test('running GPS ingest updates session distance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(workoutSessionProvider.notifier);
      n.startActivity(WorkoutActivityKind.running);
      final t0 = DateTime.utc(2026, 8, 17, 14);
      n.ingestGpsFix(GpsFix(latitude: 40.0, longitude: -74.0, at: t0));
      n.ingestGpsFix(
        GpsFix(
          latitude: 40.0004,
          longitude: -74.0,
          at: t0.add(const Duration(seconds: 10)),
        ),
      );
      final state = container.read(workoutSessionProvider);
      expect(state.distanceMeters, greaterThan(40));
      expect(state.visibleMetrics, contains(WorkoutMetricId.distance));
      expect(state.sessionSteps, greaterThan(0));
      n.stop();
    });

    test('denied GPS hides distance tiles', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(workoutSessionProvider.notifier).startActivity(
            WorkoutActivityKind.running,
            gpsDenied: true,
          );
      final state = container.read(workoutSessionProvider);
      expect(state.visibleMetrics, isNot(contains(WorkoutMetricId.distance)));
      expect(state.visibleMetrics, contains(WorkoutMetricId.elapsed));
      container.read(workoutSessionProvider.notifier).stop();
    });

    test('HIIT setup values flow into session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(workoutSessionProvider.notifier).startHiit(
            workSeconds: 30,
            restSeconds: 15,
            rounds: 4,
          );
      final state = container.read(workoutSessionProvider);
      expect(state.hiitWorkSeconds, 30);
      expect(state.hiitRestSeconds, 15);
      expect(state.hiitRounds, 4);
      expect(state.phases.length, 7);
      container.read(workoutSessionProvider.notifier).stop();
    });

    test('cardio custom metrics stay on the session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(workoutSessionProvider.notifier).startActivity(
            WorkoutActivityKind.cardio,
            enabledMetrics: const [
              WorkoutMetricId.elapsed,
              WorkoutMetricId.calories,
              WorkoutMetricId.activeMinutes,
            ],
          );
      final state = container.read(workoutSessionProvider);
      expect(state.visibleMetrics, contains(WorkoutMetricId.calories));
      expect(state.visibleMetrics, isNot(contains(WorkoutMetricId.heartRate)));
      container.read(workoutSessionProvider.notifier).stop();
    });

    test('strength live set editor updates current phase', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(workoutSessionProvider.notifier);
      n.startActivity(WorkoutActivityKind.strength);
      n.addExerciseToSession(
        ExerciseLibrary.byName('Bench Press')!.toExercise(weightKg: 61),
      );
      n.updateCurrentSet(reps: 8, weightKg: WorkoutMetricCatalog.lbToKg(145));
      final phase = container.read(workoutSessionProvider).currentPhase;
      expect(phase?.reps, 8);
      expect(phase?.weightKg, closeTo(WorkoutMetricCatalog.lbToKg(145), 0.2));
      n.stop();
    });

    test('set types cycle and warmup is excluded from volume', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(workoutSessionProvider.notifier);
      n.startActivity(WorkoutActivityKind.strength);
      n.addExerciseToSession(
        ExerciseLibrary.byName('Bench Press')!.toExercise(weightKg: 60),
      );
      n.updateCurrentSet(reps: 8, weightKg: 60);
      expect(
        container.read(workoutSessionProvider).currentPhase?.setType,
        WorkoutSetType.working,
      );
      n.cycleSetType(0);
      expect(
        container.read(workoutSessionProvider).currentPhase?.setType,
        WorkoutSetType.warmup,
      );
      n.completeSet();
      expect(
        container.read(workoutSessionProvider).phases.first.completed,
        isTrue,
      );
      expect(
        container.read(workoutSessionProvider).currentPhase?.kind,
        WorkoutTimerKind.rest,
      );
      n.finish();
      await n.saveToHistory();
      final entry = container.read(workoutHistoryProvider).entries.first;
      expect(entry.setLogs, isNotEmpty);
      expect(entry.setLogs.first.setType, WorkoutSetType.warmup);
      expect(entry.trainingVolumeKg, isNull);
    });

    test('completing the last set does not auto-finish', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(workoutSessionProvider.notifier);
      n.startRoutine(
        WorkoutRoutine(
          id: 'one',
          name: 'Single',
          exercises: const [
            WorkoutExercise(
              id: 'ex1',
              name: 'Plank',
              sets: 1,
              durationSeconds: 20,
              restSeconds: 0,
            ),
          ],
        ),
      );
      n.completeSet();
      final state = container.read(workoutSessionProvider);
      expect(state.summaryPending, isFalse);
      expect(state.currentPhase?.completed, isTrue);
      n.stop();
    });

    test('skip rest leaves the next working set current', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(workoutSessionProvider.notifier);
      n.startActivity(WorkoutActivityKind.strength);
      n.addExerciseToSession(
        ExerciseLibrary.byName('Push-up')!.toExercise(),
      );
      n.completeSet();
      expect(container.read(workoutSessionProvider).isResting, isTrue);
      n.skipRest();
      expect(container.read(workoutSessionProvider).isResting, isFalse);
      expect(
        container.read(workoutSessionProvider).currentPhase?.kind,
        WorkoutTimerKind.exercise,
      );
      n.stop();
    });

    test('indoor cardio stays off phone GPS', () {
      expect(
        WorkoutActivityKind.treadmill.hubCategory,
        WorkoutHubCategory.cardio,
      );
      expect(WorkoutActivityKind.treadmill.usesGpsTrack, isFalse);
      expect(
        WorkoutMetricCatalog.usesPhoneGps(WorkoutActivityKind.jumpRope),
        isFalse,
      );
      expect(
        WorkoutMetricCatalog.forKind(WorkoutActivityKind.rowing),
        isNot(contains(WorkoutMetricId.distance)),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(workoutSessionProvider.notifier)
          .startActivity(WorkoutActivityKind.elliptical);
      final state = container.read(workoutSessionProvider);
      expect(state.playMode, WorkoutPlayMode.activity);
      expect(state.visibleMetrics, isNot(contains(WorkoutMetricId.route)));
      container.read(workoutSessionProvider.notifier).stop();
    });

    test('calisthenics catalog uses adaptive fields', () {
      final plank = ExerciseLibrary.byName('Plank')!;
      expect(plank.usesDuration, isTrue);
      expect(plank.prescriptionLabel, contains('s'));
      final pushUp = ExerciseLibrary.calisthenics
          .firstWhere((item) => item.name == 'Push-up');
      expect(pushUp.defaultReps, greaterThan(0));
      expect(pushUp.usesDuration, isFalse);
      final weighted = ExerciseLibrary.byName('Weighted Pull-up')!;
      expect(weighted.usesWeight, isTrue);
      expect(weighted.toExercise().weightKg, isNotNull);
      expect(
        ExerciseLibrary.calisthenics.map((e) => e.name),
        containsAll(['Chin-up', 'Sit-up', 'Leg Raise', 'Muscle-up']),
      );
    });

    test('calisthenics quick start is a set-based draft', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(workoutSessionProvider.notifier);
      n.startActivity(WorkoutActivityKind.calisthenics);
      expect(
        container.read(workoutSessionProvider).activityKind,
        WorkoutActivityKind.calisthenics,
      );
      expect(container.read(workoutSessionProvider).phases, isEmpty);
      n.addExerciseToSession(ExerciseLibrary.byName('Plank')!.toExercise());
      final phase = container.read(workoutSessionProvider).currentPhase;
      expect(phase?.reps, isNull);
      expect(phase?.seconds, greaterThan(0));
      expect(
        container.read(workoutSessionProvider).activityKind,
        WorkoutActivityKind.calisthenics,
      );
      n.stop();
    });

    test('unknown activity kind JSON falls back', () {
      expect(
        WorkoutActivityKind.fromJson('not-a-real-kind'),
        WorkoutActivityKind.custom,
      );
      final routine = WorkoutRoutine.fromJson({
        'id': 'r',
        'name': 'Legacy',
        'exercises': const [],
      });
      expect(routine.activityKind, WorkoutActivityKind.strength);
    });

    test('routine estimates minutes and muscle groups', () {
      final routine = WorkoutRoutine(
        id: 'x',
        name: 'Push session',
        exercises: const [
          WorkoutExercise(
            id: '1',
            name: 'Push-up',
            muscleGroup: MuscleGroup.chest,
            sets: 3,
            reps: 10,
            restSeconds: 45,
          ),
        ],
      );
      expect(routine.muscleGroupSummary, contains('Chest'));
      expect(routine.estimatedMinutes, greaterThan(0));
    });

    test('builder kinds omit cardio machines', () {
      expect(
        WorkoutActivityKindX.builderKinds,
        isNot(contains(WorkoutActivityKind.treadmill)),
      );
      expect(
        WorkoutActivityKindX.builderKinds,
        contains(WorkoutActivityKind.calisthenics),
      );
    });

    test('routine notes persist on the model', () {
      final routine = WorkoutRoutine(
        id: 'r1',
        name: 'Chest',
        exercises: const [],
        notes: 'Left shoulder felt tight.',
      );
      final roundTrip = WorkoutRoutine.fromJson(routine.toJson());
      expect(roundTrip.notes, 'Left shoulder felt tight.');
    });
  });

  group('Notes', () {
    test('filter all is separate from general category', () async {
      final notes = NotesController();
      await notes.restore();
      await notes.addNote('Left shoulder felt tight today.', category: NoteCategories.workout);
      await notes.addNote('Slept poorly.', category: NoteCategories.sleep);
      expect(notes.state.notes, hasLength(2));
      expect(NoteCategories.filters, contains(NoteCategories.allFilter));
      expect(NoteCategories.label(NoteCategories.vital), 'Vital reading');
    });
  });

  group('AI coach', () {
    const engine = CoachVitalEngine();

    test('builds structured chest workout, not only prose', () {
      final workout = engine.buildStructuredWorkout('Build me a 40-minute chest workout.');
      expect(workout.activityKind, WorkoutActivityKind.strength);
      expect(workout.exercises, isNotEmpty);
      expect(workout.exercises.first.sets, greaterThan(0));
      expect(
        workout.exercises.any((e) => e.muscleGroup == MuscleGroup.chest),
        isTrue,
      );
    });

    test('dumbbell request stays on dumbbell equipment', () {
      final workout = engine.buildStructuredWorkout(
        'Build a workout using only dumbbells.',
      );
      expect(workout.exercises, isNotEmpty);
      expect(
        workout.exercises.every(
          (e) => (e.equipment ?? '').toLowerCase().contains('dumbbell'),
        ),
        isTrue,
      );
    });

    test('does not invent HRV when asking about recovery', () {
      final reply = engine.reply(
        userText: 'How is my recovery?',
        session: AppSession.initial(),
        health: null,
        recentNoteSnippets: const [],
        advanced: false,
      );
      expect(reply.toLowerCase(), contains('won’t invent'));
    });
  });

  group('BLE prep', () {
    test('RSSI maps to human signal labels', () {
      expect(BleSignal.label(-48), 'Strong');
      expect(BleSignal.label(-65), 'Good');
      expect(BleSignal.label(-80), 'Medium');
      expect(BleSignal.label(null), 'Unknown');
    });

    test('ready state is a linked connection', () {
      expect(DeviceConnectionState.ready.isLinked, isTrue);
      expect(DeviceConnectionState.ready.label, 'Ready');
      expect(DeviceConnectionState.scanning.label, 'Searching');
    });
  });
}
