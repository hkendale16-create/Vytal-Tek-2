import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/timers/clock_controllers.dart';
import 'package:vytal_tek/workouts/workout_controllers.dart';
import 'package:vytal_tek/workouts/workout_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 5 timer unification', () {
    test('countdown configures and starts from total seconds', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final clock = container.read(countdownProvider.notifier);
      clock.startForTotalSeconds(75);
      final state = container.read(countdownProvider);
      expect(state.running, isTrue);
      expect(state.hours, 0);
      expect(state.minutes, 1);
      expect(state.seconds, 15);
      expect(state.remainingSeconds(), 75);
    });

    test('workout prefs persist auto-rest and default rest', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(workoutPrefsProvider.notifier).setAutoRestEnabled(false);
      await container
          .read(workoutPrefsProvider.notifier)
          .setDefaultRestSeconds(120);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('vytal.workouts.auto_rest.v1'), isFalse);
      expect(prefs.getInt('vytal.workouts.default_rest_sec.v1'), 120);

      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      await fresh.read(workoutPrefsProvider.notifier).restore();
      expect(fresh.read(workoutPrefsProvider).autoRestEnabled, isFalse);
      expect(fresh.read(workoutPrefsProvider).defaultRestSeconds, 120);
    });

    test('workout rest starts shared countdown when auto-rest is on', () {
      final container = ProviderContainer();
      try {
        final routine = WorkoutRoutine(
          id: 'rest-test',
          name: 'Rest',
          exercises: const [
            WorkoutExercise(
              id: 'ex1',
              name: 'Press',
              sets: 2,
              durationSeconds: 10,
              restSeconds: 5,
            ),
          ],
        );

        final session = container.read(workoutSessionProvider.notifier);
        session.startRoutine(routine);
        session.completeSet();

        expect(container.read(workoutSessionProvider).isResting, isTrue);
        expect(container.read(countdownProvider).running, isTrue);
        expect(container.read(countdownProvider).remainingSeconds(), 5);
        session.stop();
      } finally {
        container.dispose();
      }
    });

    testWidgets('shared countdown completion advances workout rest phase',
        (tester) async {
      final container = ProviderContainer();
      try {
        final routine = WorkoutRoutine(
          id: 'rest-advance',
          name: 'Rest',
          exercises: const [
            WorkoutExercise(
              id: 'ex1',
              name: 'Press',
              sets: 2,
              durationSeconds: 10,
              restSeconds: 5,
            ),
          ],
        );

        final session = container.read(workoutSessionProvider.notifier);
        session.startRoutine(routine);
        session.completeSet();

        await tester.pump(const Duration(seconds: 6));
        expect(container.read(countdownProvider).completed, isTrue);
        expect(
          container.read(workoutSessionProvider).currentPhase?.setNumber,
          2,
        );
        session.stop();
        container.read(countdownProvider.notifier).reset();
      } finally {
        container.dispose();
      }
    });

    testWidgets('workout rest uses local timer when auto-rest is off',
        (tester) async {
      final container = ProviderContainer();
      try {
        await container
            .read(workoutPrefsProvider.notifier)
            .setAutoRestEnabled(false);

        final routine = WorkoutRoutine(
          id: 'local-rest',
          name: 'Local',
          exercises: const [
            WorkoutExercise(
              id: 'ex1',
              name: 'Row',
              sets: 2,
              durationSeconds: 10,
              restSeconds: 3,
            ),
          ],
        );

        final session = container.read(workoutSessionProvider.notifier);
        session.startRoutine(routine);
        session.completeSet();

        expect(container.read(workoutSessionProvider).isResting, isTrue);
        expect(container.read(countdownProvider).running, isFalse);

        await tester.pump(const Duration(seconds: 4));
        expect(
          container.read(workoutSessionProvider).currentPhase?.setNumber,
          2,
        );
        session.stop();
      } finally {
        container.dispose();
      }
    });
  });
}
