import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/connection/device_connection_controller.dart';
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
}

final todayHealthProvider = FutureProvider<TodayHealthSnapshot>((ref) async {
  final session = ref.watch(appSessionProvider);
  final connection = ref.watch(deviceConnectionProvider);
  final device = ref.watch(wearableDeviceProvider);

  final heart = await device.getHeartRate();
  final hrv = await device.getHrv();
  final spo2 = await device.getSpo2();
  final temperature = await device.getTemperature();
  final sleep = await device.getSleep();
  final battery = await device.getBattery();

  final isDemo = session.demoModeEnabled &&
      (connection.activeDevice?.isDemo == true || device.adapterId == 'demo');

  // Demo-only derived presentation values — clearly labeled Demo.
  int? readiness;
  String readinessMessage;
  int? steps;
  int? calories;

  if (isDemo) {
    readiness = 92;
    readinessMessage = 'Demo readiness for UI review — not a clinical score.';
    steps = 7428;
    calories = 1428;
  } else if (session.operatingMode == OperatingMode.appOnly) {
    readiness = null;
    readinessMessage =
        'No wearable readings yet. Readiness personalizes after pairing and baseline learning.';
  } else if (!heart.hasValue && !sleep.hasValue && !hrv.hasValue) {
    readiness = null;
    readinessMessage = session.baselineState.userFacingMessage;
  } else {
    // Connected with some data, but no invented composite score yet.
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
        session.operatingMode == OperatingMode.connected || isDemo,
  );
});
