import '../domain/models/monitoring_mode.dart';
import 'monitoring_signals.dart';

/// Pure automatic switching logic — unit-testable, no platform side effects.
///
/// Priority (highest first):
/// 1. Manual override when automatic mode is OFF
/// 2. Background gate (no prohibited hidden work)
/// 3. Active workout / intentional live session
/// 4. Battery saver / critical battery → Standby
/// 5. Sleep → Standby
/// 6. Long inactivity → Standby
/// 7. Otherwise Normal (charging can prefer Normal after workout)
class MonitoringEngine {
  const MonitoringEngine();

  MonitoringDecision decide({
    required MonitoringMode current,
    required MonitoringSignals signals,
  }) {
    // Manual mode always available — never trap the user in automatic.
    if (!signals.automaticMonitoringEnabled) {
      final mode = signals.manualMode ?? current;
      return MonitoringDecision(
        mode: mode,
        reason: MonitoringSwitchReason.manualOverride,
        allowHighFrequency: mode == MonitoringMode.active &&
            signals.appInForeground,
        allowBackgroundWork: signals.backgroundMonitoringEnabled &&
            signals.appInForeground == false,
      );
    }

    if (!signals.appInForeground && !signals.backgroundMonitoringEnabled) {
      return const MonitoringDecision(
        mode: MonitoringMode.standby,
        reason: MonitoringSwitchReason.backgroundMonitoringDisabled,
        allowHighFrequency: false,
        allowBackgroundWork: false,
      );
    }

    if (!signals.appInForeground && signals.backgroundMonitoringEnabled) {
      // Platform-safe reduction while backgrounded — never keep Active FPS.
      return MonitoringDecision(
        mode: signals.workoutActive
            ? MonitoringMode.normal
            : MonitoringMode.standby,
        reason: MonitoringSwitchReason.appBackgrounded,
        allowHighFrequency: false,
        allowBackgroundWork: true,
      );
    }

    if (signals.workoutActive || signals.sustainedMovement) {
      return const MonitoringDecision(
        mode: MonitoringMode.active,
        reason: MonitoringSwitchReason.workoutStarted,
        allowHighFrequency: true,
        allowBackgroundWork: false,
      );
    }

    final wearableLow = signals.wearableBatteryPercent != null &&
        signals.wearableBatteryPercent! <=
            MonitoringSignals.wearableLowBatteryThreshold &&
        !signals.isCharging;
    final phoneLow = signals.phoneBatteryPercent != null &&
        signals.phoneBatteryPercent! <=
            MonitoringSignals.phoneLowBatteryThreshold &&
        !signals.isCharging;

    if (signals.phoneBatterySaver || wearableLow || phoneLow) {
      final reason = signals.phoneBatterySaver
          ? MonitoringSwitchReason.batterySaver
          : (wearableLow
              ? MonitoringSwitchReason.wearableLowBattery
              : MonitoringSwitchReason.phoneLowBattery);
      return MonitoringDecision(
        mode: MonitoringMode.standby,
        reason: reason,
        allowHighFrequency: false,
        allowBackgroundWork: signals.backgroundMonitoringEnabled,
      );
    }

    if (signals.isSleeping) {
      return MonitoringDecision(
        mode: MonitoringMode.standby,
        reason: MonitoringSwitchReason.sleeping,
        allowHighFrequency: false,
        allowBackgroundWork: signals.backgroundMonitoringEnabled,
      );
    }

    if (signals.inactiveFor >= MonitoringSignals.inactivityStandbyThreshold) {
      return const MonitoringDecision(
        mode: MonitoringMode.standby,
        reason: MonitoringSwitchReason.sustainedInactivity,
        allowHighFrequency: false,
        allowBackgroundWork: false,
      );
    }

    // Returning from workout / default daily use.
    if (current == MonitoringMode.active) {
      return MonitoringDecision(
        mode: MonitoringMode.normal,
        reason: signals.isCharging
            ? MonitoringSwitchReason.chargingAllowsNormal
            : MonitoringSwitchReason.workoutEnded,
        allowHighFrequency: false,
        allowBackgroundWork: false,
      );
    }

    return MonitoringDecision(
      mode: MonitoringMode.normal,
      reason: signals.isCharging
          ? MonitoringSwitchReason.chargingAllowsNormal
          : MonitoringSwitchReason.userPreferenceDefault,
      allowHighFrequency: false,
      allowBackgroundWork: false,
    );
  }
}
