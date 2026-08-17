import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/connection/device_connection_controller.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../../domain/models/operating_mode.dart';
import '../../domain/models/personal_profile.dart';
import '../../state/app_session_controller.dart';

/// Aggregated Today / health surface values.
///
/// Never invents vitals. Demo values are only used when Demo mode is on and a
/// demo device is active. Otherwise readings come from the wearable adapter or
/// remain null / unsupported.
///
/// Data-usage notes: App-Only with no paired device skips adapter reads.
/// Session watches are selective so monitoring-mode churn does not re-query
/// sensors.
class TodayHealthSnapshot {
  const TodayHealthSnapshot({
    required this.readinessScore,
    required this.readinessMessage,
    required this.heartRate,
    required this.hrv,
    required this.spo2,
    required this.temperature,
    required this.sleep,
    required this.battery,
    required this.steps,
    required this.calories,
    required this.provenance,
    required this.hasWearableContext,
  });

  final int? readinessScore;
  final String readinessMessage;
  final HealthMetricReading<int> heartRate;
  final HealthMetricReading<int> hrv;
  final HealthMetricReading<int> spo2;
  final HealthMetricReading<double> temperature;
  final HealthMetricReading<Duration> sleep;
  final HealthMetricReading<int> battery;
  final int? steps;
  final int? calories;
  final DataProvenance provenance;
  final bool hasWearableContext;

  /// Empty App-Only snapshot — no adapter / BLE reads.
  static TodayHealthSnapshot appOnlyEmpty({
    required String readinessMessage,
  }) {
    return TodayHealthSnapshot(
      readinessScore: null,
      readinessMessage: readinessMessage,
      heartRate: unsupportedReading(
        key: HealthMetricKeys.heartRate,
        displayName: 'Heart Rate',
        unit: 'BPM',
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
      hasWearableContext: false,
    );
  }
}

/// Fields that actually affect Today vitals — ignore monitoring-mode churn.
final todayHealthProvider = FutureProvider<TodayHealthSnapshot>((ref) async {
  // Selective watch: monitoring mode / entitlements must NOT re-hit sensors.
  final key = ref.watch(
    appSessionProvider.select(
      (s) => (
        demoModeEnabled: s.demoModeEnabled,
        operatingMode: s.operatingMode,
        pairedDeviceId: s.pairedDevice?.id,
        pairedIsDemo: s.pairedDevice?.isDemo ?? false,
        baselineState: s.baselineState,
      ),
    ),
  );
  final connection = ref.watch(
    deviceConnectionProvider.select(
      (c) => (
        activeId: c.activeDevice?.id,
        activeIsDemo: c.activeDevice?.isDemo ?? false,
        connectionState: c.state,
      ),
    ),
  );

  final needsDeviceReads = key.demoModeEnabled ||
      key.pairedDeviceId != null ||
      connection.activeId != null ||
      key.operatingMode == OperatingMode.connected;

  if (!needsDeviceReads) {
    return TodayHealthSnapshot.appOnlyEmpty(
      readinessMessage:
          'No wearable readings yet. Readiness personalizes after pairing and baseline learning.',
    );
  }

  final device = ref.watch(wearableDeviceProvider);

  // Parallelize independent metric reads to cut wall-clock BLE/cache latency.
  final results = await Future.wait([
    device.getHeartRate(),
    device.getHrv(),
    device.getSpo2(),
    device.getTemperature(),
    device.getSleep(),
    device.getBattery(),
  ]);

  final heart = results[0] as HealthMetricReading<int>;
  final hrv = results[1] as HealthMetricReading<int>;
  final spo2 = results[2] as HealthMetricReading<int>;
  final temperature = results[3] as HealthMetricReading<double>;
  final sleep = results[4] as HealthMetricReading<Duration>;
  final battery = results[5] as HealthMetricReading<int>;

  final isDemo = key.demoModeEnabled &&
      (connection.activeIsDemo ||
          key.pairedIsDemo ||
          device.adapterId == 'demo');

  int? readiness;
  String readinessMessage;
  int? steps;
  int? calories;

  if (isDemo) {
    readiness = 92;
    readinessMessage = 'Demo readiness for UI review — not a clinical score.';
    steps = 7428;
    calories = 1428;
  } else if (key.operatingMode == OperatingMode.appOnly) {
    readiness = null;
    readinessMessage =
        'No wearable readings yet. Readiness personalizes after pairing and baseline learning.';
  } else if (!heart.hasValue && !sleep.hasValue && !hrv.hasValue) {
    readiness = null;
    readinessMessage = key.baselineState.userFacingMessage;
  } else {
    readiness = null;
    readinessMessage =
        'Wearable connected. Composite readiness scoring arrives after baseline learning — individual metrics below are from sync.';
  }

  return TodayHealthSnapshot(
    readinessScore: readiness,
    readinessMessage: readinessMessage,
    heartRate: heart,
    hrv: hrv,
    spo2: spo2,
    temperature: temperature,
    sleep: sleep,
    battery: battery,
    steps: steps,
    calories: calories,
    provenance: isDemo ? DataProvenance.demo : DataProvenance.wearable,
    hasWearableContext:
        key.operatingMode == OperatingMode.connected || isDemo,
  );
});
