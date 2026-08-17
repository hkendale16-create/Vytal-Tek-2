import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/domain/devices/wearable_device.dart';
import 'package:vytal_tek/domain/models/data_provenance.dart';
import 'package:vytal_tek/domain/models/health_metric.dart';
import 'package:vytal_tek/domain/models/operating_mode.dart';
import 'package:vytal_tek/features/ai/coach_vital_engine.dart';
import 'package:vytal_tek/features/today/today_health_provider.dart';
import 'package:vytal_tek/notes/notes_controller.dart';
import 'package:vytal_tek/state/app_session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 6 Coach Vital', () {
    const engine = CoachVitalEngine();

    test('refuses diagnosis requests', () {
      final session = AppSession.initial();
      final reply = engine.reply(
        userText: 'Can you diagnose my chest pain?',
        session: session,
        health: null,
        recentNoteSnippets: const [],
        advanced: false,
      );
      expect(reply.toLowerCase(), contains('can’t diagnose'));
      expect(reply, contains(CoachVitalEngine.safetyFooter));
    });

    test('does not invent heart rate when missing', () {
      final session = AppSession.initial();
      final reply = engine.reply(
        userText: 'What is my heart rate?',
        session: session,
        health: TodayHealthSnapshot.appOnlyEmpty(
          readinessMessage: 'none',
        ),
        recentNoteSnippets: const [],
        advanced: false,
      );
      expect(reply.toLowerCase(), contains('won’t invent'));
      expect(reply.contains(RegExp(r'\b\d{2,3}\s*BPM\b')), isFalse);
    });

    test('reports verified heart rate when present', () {
      final session = AppSession.initial().copyWith(
        operatingMode: OperatingMode.connected,
      );
      final health = TodayHealthSnapshot(
        readinessScore: null,
        readinessMessage: 'ok',
        heartRate: const HealthMetricReading<int>(
          key: HealthMetricKeys.heartRate,
          displayName: 'Heart Rate',
          value: 68,
          unit: 'BPM',
          provenance: DataProvenance.wearable,
          freshness: ReadingFreshness.lastSynced,
        ),
        hrv: unsupportedReading(
          key: HealthMetricKeys.hrv,
          displayName: 'HRV',
          unit: 'ms',
        ),
        spo2: unsupportedReading(
          key: HealthMetricKeys.spo2,
          displayName: 'SpO₂',
          unit: '%',
        ),
        temperature: unsupportedReading(
          key: HealthMetricKeys.temperature,
          displayName: 'Temperature',
          unit: '°C',
        ),
        sleep: unsupportedReading(
          key: HealthMetricKeys.sleepDuration,
          displayName: 'Sleep',
        ),
        battery: unsupportedReading(
          key: HealthMetricKeys.wearableBattery,
          displayName: 'Battery',
          unit: '%',
        ),
        steps: null,
        calories: null,
        provenance: DataProvenance.wearable,
        hasWearableContext: true,
      );
      final reply = engine.reply(
        userText: 'What is my heart rate?',
        session: session,
        health: health,
        recentNoteSnippets: const [],
        advanced: false,
      );
      expect(reply, contains('68'));
      expect(reply, contains('BPM'));
      expect(reply, isNot(contains('won’t invent')));
    });
  });

  group('Phase 7 notes', () {
    test('notes persist and expose AI snippets without sensor claims', () async {
      final controller = NotesController();
      await controller.restore();
      await controller.addNote('Felt strong after intervals');
      await controller.addReminder(
        title: 'Wind-down',
        when: DateTime.now().toUtc().add(const Duration(hours: 3)),
      );
      expect(controller.state.notes, hasLength(1));
      expect(controller.state.reminders, hasLength(1));
      expect(controller.aiContextSnippets().first, contains('intervals'));

      final reloaded = NotesController();
      await reloaded.restore();
      expect(reloaded.state.notes.first.body, contains('intervals'));
      expect(reloaded.state.reminders.first.title, 'Wind-down');
    });
  });
}
