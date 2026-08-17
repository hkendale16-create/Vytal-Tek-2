import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../devices/connection/device_connection_controller.dart';
import '../domain/models/data_provenance.dart';
import '../features/today/today_health_provider.dart';
import '../state/app_session_controller.dart';
import 'battery_intelligence.dart';

final batteryIntelligenceProvider = Provider<BatteryInsight>((ref) {
  final session = ref.watch(
    appSessionProvider.select(
      (s) => (
        operatingMode: s.operatingMode,
        monitoringMode: s.monitoringMode,
        backgroundMonitoringEnabled: s.backgroundMonitoringEnabled,
        demoModeEnabled: s.demoModeEnabled,
      ),
    ),
  );
  final connectionBattery = ref.watch(
    deviceConnectionProvider.select((c) => c.battery?.value),
  );
  final healthBattery = ref.watch(
    todayHealthProvider.select((async) => async.valueOrNull?.battery),
  );

  final percent = connectionBattery ??
      (healthBattery?.hasValue == true ? healthBattery!.value : null);
  final isDemo = healthBattery?.provenance == DataProvenance.demo ||
      (session.demoModeEnabled && percent != null && connectionBattery == null);

  return const BatteryIntelligence().evaluate(
    wearablePercent: percent,
    isDemo: isDemo,
    operatingMode: session.operatingMode,
    monitoringMode: session.monitoringMode,
    backgroundMonitoringEnabled: session.backgroundMonitoringEnabled,
  );
});
