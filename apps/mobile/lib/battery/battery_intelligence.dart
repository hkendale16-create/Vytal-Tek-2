import '../domain/models/monitoring_mode.dart';
import '../domain/models/operating_mode.dart';

enum BatteryAlertLevel {
  ok,
  watch,
  low,
  critical,
}

class BatteryInsight {
  const BatteryInsight({
    required this.wearablePercent,
    required this.alertLevel,
    required this.headline,
    required this.tips,
    required this.estimatedSyncWindows,
    required this.isDemo,
    required this.hasWearableReading,
  });

  final int? wearablePercent;
  final BatteryAlertLevel alertLevel;
  final String headline;
  final List<String> tips;

  /// Rough remaining full-sync opportunities before recharge — null if unknown.
  final int? estimatedSyncWindows;
  final bool isDemo;
  final bool hasWearableReading;
}

/// Phase 8 — battery alerts, coarse estimates, and charging tips.
///
/// Never invents a battery %. Missing readings stay missing.
class BatteryIntelligence {
  const BatteryIntelligence();

  static const watchThreshold = 35;
  static const lowThreshold = 20;
  static const criticalThreshold = 10;

  BatteryInsight evaluate({
    required int? wearablePercent,
    required bool isDemo,
    required OperatingMode operatingMode,
    required MonitoringMode monitoringMode,
    required bool backgroundMonitoringEnabled,
  }) {
    if (wearablePercent == null) {
      return BatteryInsight(
        wearablePercent: null,
        alertLevel: BatteryAlertLevel.ok,
        headline: operatingMode == OperatingMode.appOnly
            ? 'No wearable battery yet — App-Only Mode uses phone power only.'
            : 'Wearable battery unknown until a verified reading syncs.',
        tips: const [
          'Pair and sync to see ring battery.',
          'Use Standby monitoring when you want lower sampling.',
          'Background monitoring increases phone radio use — keep it off if you are saving phone battery.',
        ],
        estimatedSyncWindows: null,
        isDemo: isDemo,
        hasWearableReading: false,
      );
    }

    final level = wearablePercent <= criticalThreshold
        ? BatteryAlertLevel.critical
        : wearablePercent <= lowThreshold
            ? BatteryAlertLevel.low
            : wearablePercent <= watchThreshold
                ? BatteryAlertLevel.watch
                : BatteryAlertLevel.ok;

    final syncCost = switch (monitoringMode) {
      MonitoringMode.active => 8,
      MonitoringMode.normal => 4,
      MonitoringMode.standby => 2,
    };
    final windows = (wearablePercent / syncCost).floor().clamp(0, 40);

    final tips = <String>[
      if (level == BatteryAlertLevel.critical || level == BatteryAlertLevel.low)
        'Charge the wearable soon. Prefer Standby until it recovers.',
      if (monitoringMode == MonitoringMode.active)
        'Active monitoring is the highest draw — end the workout session when finished.',
      if (backgroundMonitoringEnabled)
        'Background monitoring is on — expect more phone wakeups. Disable it in Settings if you need to conserve phone battery.',
      'Short syncs beat leaving a live session running.',
      'Charging tip: remove the ring from sweaty skin before charging for better contact.',
      if (isDemo) 'Demo battery is labeled Demo — not a live device reading.',
    ];

    final headline = switch (level) {
      BatteryAlertLevel.critical =>
        'Critical wearable battery ($wearablePercent%). Charge now.',
      BatteryAlertLevel.low =>
        'Low wearable battery ($wearablePercent%). Plan a charge.',
      BatteryAlertLevel.watch =>
        'Wearable battery at $wearablePercent%. Keep an eye on sync load.',
      BatteryAlertLevel.ok =>
        'Wearable battery $wearablePercent% — looking healthy for normal use.',
    };

    return BatteryInsight(
      wearablePercent: wearablePercent,
      alertLevel: level,
      headline: headline,
      tips: tips,
      estimatedSyncWindows: windows,
      isDemo: isDemo,
      hasWearableReading: true,
    );
  }
}
