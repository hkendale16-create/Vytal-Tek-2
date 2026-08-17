import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/core/motion/hud_motion_provider.dart';
import 'package:vytal_tek/domain/models/daily_health_summary.dart';
import 'package:vytal_tek/domain/models/data_provenance.dart';
import 'package:vytal_tek/domain/models/health_metric.dart';
import 'package:vytal_tek/domain/models/monitoring_mode.dart';
import 'package:vytal_tek/domain/models/workout_models.dart';
import 'package:vytal_tek/features/today/today_health_provider.dart';
import 'package:vytal_tek/health/daily_summary_analytics.dart';
import 'package:vytal_tek/health/daily_summary_store.dart';
import 'package:vytal_tek/monitoring/monitoring_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  TodayHealthSnapshot emptySnap() => TodayHealthSnapshot.appOnlyEmpty(
        readinessMessage: 'No wearable readings yet.',
      );

  TodayHealthSnapshot hrSnap(int bpm) {
    final empty = emptySnap();
    return TodayHealthSnapshot(
      readinessScore: null,
      readinessMessage: empty.readinessMessage,
      heartRate: HealthMetricReading<int>(
        key: HealthMetricKeys.heartRate,
        displayName: 'Heart Rate',
        value: bpm,
        unit: 'BPM',
        provenance: DataProvenance.wearable,
        freshness: ReadingFreshness.lastSynced,
      ),
      hrv: empty.hrv,
      spo2: empty.spo2,
      temperature: empty.temperature,
      sleep: empty.sleep,
      battery: empty.battery,
      steps: null,
      calories: null,
      provenance: DataProvenance.wearable,
      hasWearableContext: true,
    );
  }

  test('empty App-Only snapshot is not cached', () async {
    final store = DailySummaryStore();
    await store.captureSnapshot(emptySnap());
    expect(store.state.days, isEmpty);
  });

  test('capture stores present HR and leaves missing metrics null', () async {
    final store = DailySummaryStore();
    await store.captureSnapshot(hrSnap(64));
    expect(store.state.days.length, 1);
    final day = store.state.sorted.single;
    expect(day.heartRate, 64);
    expect(day.hrv, isNull);
    expect(day.sleepMinutes, isNull);
    expect(day.steps, isNull);
    expect(day.provenance, DataProvenance.wearable);
  });

  test('workout load updates the day without inventing vitals', () async {
    final store = DailySummaryStore();
    final when = DateTime(2026, 8, 17, 8);
    await store.applyWorkoutLoad([
      WorkoutHistoryEntry(
        id: 'w1',
        name: 'Run',
        activityKind: WorkoutActivityKind.running,
        durationSeconds: 1800,
        completedAt: when,
      ),
    ]);
    final day = store.state.forDay(when);
    expect(day?.workoutLoadMinutes, 30);
    expect(day?.heartRate, isNull);
  });

  test('analytics omits empty days and does not zero-fill', () {
    const analytics = DailySummaryAnalytics();
    final now = DateTime(2026, 8, 17);
    final series = analytics.series(
      summaries: [
        DailyHealthSummary(
          dayKey: '2026-08-16',
          provenance: DataProvenance.wearable,
          updatedAt: now.toUtc(),
          heartRate: 60,
        ),
        DailyHealthSummary(
          dayKey: '2026-08-17',
          provenance: DataProvenance.wearable,
          updatedAt: now.toUtc(),
          heartRate: 70,
        ),
      ],
      metric: 'Heart Rate',
      range: '7D',
      now: now,
    );
    expect(series, [60.0, 70.0]);
  });

  test('1Y uses monthly averages instead of hundreds of points', () {
    const analytics = DailySummaryAnalytics();
    final now = DateTime(2026, 8, 17);
    final days = <DailyHealthSummary>[
      for (var i = 0; i < 10; i++)
        DailyHealthSummary(
          dayKey: '2026-07-${(i + 1).toString().padLeft(2, '0')}',
          provenance: DataProvenance.wearable,
          updatedAt: now.toUtc(),
          hrv: 50,
        ),
      for (var i = 0; i < 10; i++)
        DailyHealthSummary(
          dayKey: '2026-08-${(i + 1).toString().padLeft(2, '0')}',
          provenance: DataProvenance.wearable,
          updatedAt: now.toUtc(),
          hrv: 70,
        ),
    ];
    final series = analytics.series(
      summaries: days,
      metric: 'HRV',
      range: '1Y',
      now: now,
    );
    expect(series.length, 2);
    expect(series.first, 50);
    expect(series.last, 70);
  });

  test('sleep consistency stays null without enough nights', () {
    const analytics = DailySummaryAnalytics();
    expect(analytics.sleepConsistency(const []), isNull);
    expect(
      analytics.sleepConsistency([
        DailyHealthSummary(
          dayKey: '2026-08-16',
          provenance: DataProvenance.wearable,
          updatedAt: DateTime.utc(2026, 8, 16),
          sleepMinutes: 420,
        ),
      ]),
      isNull,
    );
  });

  test('HUD motion is off in Standby', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);
    container.read(monitoringControllerProvider.notifier).selectModeManually(
          MonitoringMode.standby,
        );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(hudMotionEnabledProvider), isFalse);
  });

  test('HUD motion is off when battery saver is on', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);
    container
        .read(monitoringControllerProvider.notifier)
        .setPhoneBattery(percent: 12, batterySaver: true);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(hudMotionEnabledProvider), isFalse);
  });
}
