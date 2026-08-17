import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/core/permissions/permission_catalog.dart';
import 'package:vytal_tek/devices/connection/pairing_platform.dart';
import 'package:vytal_tek/domain/models/notes_models.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/features/ai/coach_vital_engine.dart';
import 'package:vytal_tek/notes/notes_controller.dart';
import 'package:vytal_tek/state/app_session_controller.dart';
import 'package:vytal_tek/workouts/exercise_library.dart';
import 'package:vytal_tek/workouts/workout_controllers.dart';
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
      const glow = Color(0xFF00FFD1);
      expect(glow.withValues(alpha: 0.11).a, lessThan(0.2));
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

    test('running metrics are unique from strength', () {
      expect(
        WorkoutMetricCatalog.forKind(WorkoutActivityKind.running),
        isNot(equals(
          WorkoutMetricCatalog.forKind(WorkoutActivityKind.strength),
        )),
      );
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
}
