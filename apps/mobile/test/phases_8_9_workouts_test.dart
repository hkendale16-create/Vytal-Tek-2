import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/battery/battery_intelligence.dart';
import 'package:vytal_tek/domain/models/monitoring_mode.dart';
import 'package:vytal_tek/domain/models/operating_mode.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/monitoring/monitoring_controller.dart';
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

    test('starting a routine builds phases and can complete', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final routine = WorkoutRoutine(
          id: 'test-short',
          name: 'Short',
          exercises: const [
            WorkoutExercise(
              id: 'ex1',
              name: 'Plank',
              sets: 1,
              durationSeconds: 2,
              restSeconds: 0,
            ),
          ],
        );

        final session = container.read(workoutSessionProvider.notifier);
        session.startRoutine(routine);

        var state = container.read(workoutSessionProvider);
        expect(state.running, isTrue);
        expect(state.phases, isNotEmpty);
        expect(state.remainingSeconds, 2);
        expect(
          container.read(monitoringControllerProvider).signals.workoutActive,
          isTrue,
        );

        async.elapse(const Duration(seconds: 3));
        state = container.read(workoutSessionProvider);
        expect(state.completed, isTrue);
        expect(state.running, isFalse);
        expect(
          container.read(monitoringControllerProvider).signals.workoutActive,
          isFalse,
        );
      });
    });

    test('stopwatch advances elapsed time', () {
      fakeAsync((async) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(workoutSessionProvider.notifier).startStopwatch();
        async.elapse(const Duration(seconds: 2));
        final state = container.read(workoutSessionProvider);
        expect(state.stopwatchElapsed, greaterThanOrEqualTo(1));
        container.read(workoutSessionProvider.notifier).stop();
        expect(container.read(workoutSessionProvider).phases, isEmpty);
      });
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
