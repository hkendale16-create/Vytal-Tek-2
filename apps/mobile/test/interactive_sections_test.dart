import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/battery/battery_intelligence.dart';
import 'package:vytal_tek/domain/models/operating_mode.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/features/ai/coach_vital_engine.dart';
import 'package:vytal_tek/state/app_session_controller.dart';
import 'package:vytal_tek/timers/clock_controllers.dart';
import 'package:vytal_tek/workouts/workout_controllers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Interactive timers', () {
    testWidgets('countdown start/pause/resume uses remaining time', (tester) async {
      final container = ProviderContainer();
      try {
        final clock = container.read(countdownProvider.notifier);
        clock.setMinutes(0);
        clock.setSeconds(5);
        clock.start();
        expect(container.read(countdownProvider).running, isTrue);

        await tester.pump(const Duration(seconds: 1));
        final after = container.read(countdownProvider).remainingSeconds();
        expect(after, lessThanOrEqualTo(5));
        expect(after, greaterThan(0));

        clock.pause();
        final paused = container.read(countdownProvider).remainingMs();
        await tester.pump(const Duration(seconds: 2));
        expect(container.read(countdownProvider).remainingMs(), paused);

        clock.start();
        expect(container.read(countdownProvider).running, isTrue);
        clock.reset();
        expect(container.read(countdownProvider).running, isFalse);
      } finally {
        container.dispose();
      }
    });

    testWidgets('stopwatch laps and pause', (tester) async {
      final container = ProviderContainer();
      try {
        final sw = container.read(stopwatchClockProvider.notifier);
        sw.start();
        await tester.pump(const Duration(milliseconds: 250));
        sw.lap();
        expect(container.read(stopwatchClockProvider).laps, isNotEmpty);
        sw.pause();
        final elapsed = container.read(stopwatchClockProvider).elapsedMs();
        await tester.pump(const Duration(milliseconds: 400));
        expect(container.read(stopwatchClockProvider).elapsedMs(), elapsed);
        sw.reset();
        expect(container.read(stopwatchClockProvider).elapsedMs(), 0);
      } finally {
        container.dispose();
      }
    });

    testWidgets('interval skip advances phase', (tester) async {
      final container = ProviderContainer();
      try {
        final intervals = container.read(intervalClockProvider.notifier);
        intervals.updateConfig(
          const IntervalConfig(workSeconds: 30, restSeconds: 15, rounds: 3),
        );
        intervals.start();
        expect(container.read(intervalClockProvider).phase, IntervalPhaseKind.work);
        intervals.skip();
        expect(container.read(intervalClockProvider).phase, IntervalPhaseKind.rest);
        intervals.stop();
      } finally {
        container.dispose();
      }
    });
  });

  group('Interactive workouts', () {
    testWidgets('completeSet advances routine phase', (tester) async {
      final container = ProviderContainer();
      try {
        final routine = WorkoutRoutine(
          id: 't',
          name: 'Sets',
          exercises: const [
            WorkoutExercise(
              id: 'ex1',
              name: 'Squat',
              sets: 2,
              durationSeconds: 20,
              restSeconds: 10,
            ),
          ],
        );
        final session = container.read(workoutSessionProvider.notifier);
        session.startRoutine(routine);
        expect(container.read(workoutSessionProvider).currentPhase?.kind,
            WorkoutTimerKind.exercise);
        session.completeSet();
        expect(container.read(workoutSessionProvider).currentPhase?.kind,
            WorkoutTimerKind.rest);
        session.stop();
        await tester.pump();
      } finally {
        container.dispose();
      }
    });

    testWidgets('activity workout pause keeps elapsed', (tester) async {
      final container = ProviderContainer();
      try {
        final session = container.read(workoutSessionProvider.notifier);
        session.startActivity(WorkoutActivityKind.running);
        await tester.pump(const Duration(seconds: 1));
        session.pause();
        final elapsed = container.read(workoutSessionProvider).elapsedSeconds();
        expect(elapsed, greaterThanOrEqualTo(1));
        await tester.pump(const Duration(seconds: 2));
        expect(container.read(workoutSessionProvider).elapsedSeconds(), elapsed);
        session.resume();
        expect(container.read(workoutSessionProvider).running, isTrue);
        session.finish();
        expect(container.read(workoutSessionProvider).summaryPending, isTrue);
        session.discard();
        expect(container.read(workoutSessionProvider).phases, isEmpty);
      } finally {
        container.dispose();
      }
    });

    test('saving history persists an entry', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = container.read(workoutSessionProvider.notifier);
      session.startActivity(WorkoutActivityKind.walking);
      session.finish();
      await session.saveToHistory();
      expect(container.read(workoutHistoryProvider).entries, isNotEmpty);
      expect(
        container.read(workoutHistoryProvider).entries.first.activityKind,
        WorkoutActivityKind.walking,
      );
    });
  });

  group('Coach structured workout', () {
    test('build me a workout returns structured exercises', () {
      const engine = CoachVitalEngine();
      final workout = engine.tryBuildWorkout('Build me a 30-minute workout.');
      expect(workout, isNotNull);
      expect(workout!.exercises.length, greaterThanOrEqualTo(3));
      expect(workout.exercises.first.sets, greaterThan(0));
      final reply = engine.compose(
        userText: 'Build me a 30-minute workout.',
        session: AppSession.initial(),
        health: null,
        recentNoteSnippets: const [],
        advanced: false,
      );
      expect(reply.workout, isNotNull);
      expect(reply.text.toLowerCase(), contains('structured'));
    });
  });

  group('Battery alert dedup', () {
    test('notifies once at 20% band', () {
      final dedup = BatteryAlertDedup();
      expect(dedup.shouldNotify(BatteryAlertLevel.low, 20), isTrue);
      expect(dedup.shouldNotify(BatteryAlertLevel.low, 19), isFalse);
      expect(dedup.shouldNotify(BatteryAlertLevel.low, 18), isFalse);
      expect(dedup.shouldNotify(BatteryAlertLevel.ok, 40), isFalse);
      expect(dedup.shouldNotify(BatteryAlertLevel.low, 20), isTrue);
    });
  });

  test('app-only session still has no paired device', () {
    final session = AppSession.initial();
    expect(session.operatingMode, OperatingMode.appOnly);
    expect(session.pairedDevice, isNull);
  });
}
