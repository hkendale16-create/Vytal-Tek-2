import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/battery/battery_intelligence.dart';
import 'package:vytal_tek/domain/models/monitoring_mode.dart';
import 'package:vytal_tek/domain/models/operating_mode.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/state/app_session_controller.dart';
import 'package:vytal_tek/workouts/workout_controllers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 8 Battery Intelligence', () {
    const engine = BatteryIntelligence();

    test('does not invent a percent when reading is missing', () {
      final insight = engine.evaluate(
        wearablePercent: null,
        isDemo: false,
        operatingMode: OperatingMode.appOnly,
        monitoringMode: MonitoringMode.normal,
        backgroundMonitoringEnabled: false,
      );
      expect(insight.hasWearableReading, isFalse);
      expect(insight.wearablePercent, isNull);
      expect(insight.estimatedSyncWindows, isNull);
      expect(insight.headline.toLowerCase(), contains('app-only'));
    });

    test('maps thresholds and estimates sync windows from real %', () {
      final low = engine.evaluate(
        wearablePercent: 18,
        isDemo: false,
        operatingMode: OperatingMode.connected,
        monitoringMode: MonitoringMode.normal,
        backgroundMonitoringEnabled: false,
      );
      expect(low.alertLevel, BatteryAlertLevel.low);
      expect(low.wearablePercent, 18);
      expect(low.estimatedSyncWindows, 4); // 18 / 4

      final critical = engine.evaluate(
        wearablePercent: 8,
        isDemo: true,
        operatingMode: OperatingMode.connected,
        monitoringMode: MonitoringMode.active,
        backgroundMonitoringEnabled: true,
      );
      expect(critical.alertLevel, BatteryAlertLevel.critical);
      expect(critical.tips.any((t) => t.toLowerCase().contains('demo')), isTrue);
      expect(
        critical.tips.any((t) => t.toLowerCase().contains('background')),
        isTrue,
      );
    });
  });

  group('Workouts timer engine', () {
    test('built-in routines are available without a wearable', () {
      final routines = WorkoutRoutine.builtIns();
      expect(routines, isNotEmpty);
      expect(routines.every((r) => r.builtIn), isTrue);
    });

    test('routine expands into exercise and rest phases', () {
      final routine = WorkoutRoutine(
        id: 'test',
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

      final phases = WorkoutSessionController.buildPhases(routine);
      expect(phases.length, 3); // work, rest, work
      expect(phases[0].kind, WorkoutTimerKind.exercise);
      expect(phases[1].kind, WorkoutTimerKind.rest);
      expect(phases[2].kind, WorkoutTimerKind.exercise);
      expect(phases[0].seconds, 20);
    });

    testWidgets('session pause/resume/stop without leaking timers',
        (tester) async {
      final container = ProviderContainer();
      try {
        final routine = WorkoutRoutine(
          id: 'test-short',
          name: 'Short',
          exercises: const [
            WorkoutExercise(
              id: 'ex1',
              name: 'Plank',
              sets: 1,
              durationSeconds: 30,
              restSeconds: 0,
            ),
          ],
        );

        final session = container.read(workoutSessionProvider.notifier);
        session.startRoutine(routine);

        var state = container.read(workoutSessionProvider);
        expect(state.running, isTrue);
        expect(state.remainingSeconds, 30);

        session.pause();
        expect(container.read(workoutSessionProvider).running, isFalse);

        session.resume();
        expect(container.read(workoutSessionProvider).running, isTrue);

        await tester.pump(const Duration(seconds: 1));
        state = container.read(workoutSessionProvider);
        expect(state.elapsedSeconds(), greaterThanOrEqualTo(1));
        expect(state.currentPhase?.kind, WorkoutTimerKind.exercise);

        session.stop();
        expect(container.read(workoutSessionProvider).phases, isEmpty);
      } finally {
        container.dispose();
      }
    });
  });

  group('Phase 9 App-Only smoke', () {
    test('session starts in App-Only with no paired device', () {
      final session = AppSession.initial();
      expect(session.operatingMode, OperatingMode.appOnly);
      expect(session.pairedDevice, isNull);
      expect(session.demoModeEnabled, isFalse);
    });

    test('battery provider path stays empty offline', () {
      const engine = BatteryIntelligence();
      final insight = engine.evaluate(
        wearablePercent: null,
        isDemo: false,
        operatingMode: OperatingMode.appOnly,
        monitoringMode: MonitoringMode.standby,
        backgroundMonitoringEnabled: false,
      );
      expect(insight.hasWearableReading, isFalse);
      expect(RegExp(r'\d+%').hasMatch(insight.headline), isFalse);
    });
  });
}
