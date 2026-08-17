import '../domain/models/monitoring_mode.dart';

/// Why the engine recommended or applied a mode change.
enum MonitoringSwitchReason {
  manualOverride,
  workoutStarted,
  workoutEnded,
  sustainedInactivity,
  wearableLowBattery,
  phoneLowBattery,
  batterySaver,
  sleeping,
  chargingAllowsNormal,
  userPreferenceDefault,
  appBackgrounded,
  appForegrounded,
  backgroundMonitoringDisabled,
}

extension MonitoringSwitchReasonX on MonitoringSwitchReason {
  String get label => switch (this) {
        MonitoringSwitchReason.manualOverride => 'Manual selection',
        MonitoringSwitchReason.workoutStarted => 'Workout detected',
        MonitoringSwitchReason.workoutEnded => 'Workout ended',
        MonitoringSwitchReason.sustainedInactivity => 'Long inactivity',
        MonitoringSwitchReason.wearableLowBattery => 'Wearable battery low',
        MonitoringSwitchReason.phoneLowBattery => 'Phone battery low',
        MonitoringSwitchReason.batterySaver => 'Battery saver',
        MonitoringSwitchReason.sleeping => 'Sleep period',
        MonitoringSwitchReason.chargingAllowsNormal => 'Device charging',
        MonitoringSwitchReason.userPreferenceDefault => 'Default preference',
        MonitoringSwitchReason.appBackgrounded => 'App in background',
        MonitoringSwitchReason.appForegrounded => 'App returned to foreground',
        MonitoringSwitchReason.backgroundMonitoringDisabled =>
          'Background monitoring off',
      };
}

/// Observable inputs for automatic mode switching.
///
/// Engine never invents sensor values — callers supply only known signals.
class MonitoringSignals {
  const MonitoringSignals({
    this.workoutActive = false,
    this.sustainedMovement = false,
    this.inactiveFor = Duration.zero,
    this.wearableBatteryPercent,
    this.phoneBatteryPercent,
    this.phoneBatterySaver = false,
    this.isSleeping = false,
    this.isCharging = false,
    this.appInForeground = true,
    this.backgroundMonitoringEnabled = false,
    this.automaticMonitoringEnabled = true,
    this.manualMode,
    this.now,
  });

  final bool workoutActive;
  final bool sustainedMovement;
  final Duration inactiveFor;
  final int? wearableBatteryPercent;
  final int? phoneBatteryPercent;
  final bool phoneBatterySaver;
  final bool isSleeping;
  final bool isCharging;
  final bool appInForeground;
  final bool backgroundMonitoringEnabled;
  final bool automaticMonitoringEnabled;

  /// When set and automatic mode is OFF, this mode is honored.
  final MonitoringMode? manualMode;

  final DateTime? now;

  static const inactivityStandbyThreshold = Duration(minutes: 45);
  static const wearableLowBatteryThreshold = 20;
  static const phoneLowBatteryThreshold = 15;

  MonitoringSignals copyWith({
    bool? workoutActive,
    bool? sustainedMovement,
    Duration? inactiveFor,
    int? wearableBatteryPercent,
    int? phoneBatteryPercent,
    bool? phoneBatterySaver,
    bool? isSleeping,
    bool? isCharging,
    bool? appInForeground,
    bool? backgroundMonitoringEnabled,
    bool? automaticMonitoringEnabled,
    MonitoringMode? manualMode,
    DateTime? now,
    bool clearWearableBattery = false,
    bool clearPhoneBattery = false,
    bool clearManualMode = false,
  }) {
    return MonitoringSignals(
      workoutActive: workoutActive ?? this.workoutActive,
      sustainedMovement: sustainedMovement ?? this.sustainedMovement,
      inactiveFor: inactiveFor ?? this.inactiveFor,
      wearableBatteryPercent: clearWearableBattery
          ? null
          : (wearableBatteryPercent ?? this.wearableBatteryPercent),
      phoneBatteryPercent: clearPhoneBattery
          ? null
          : (phoneBatteryPercent ?? this.phoneBatteryPercent),
      phoneBatterySaver: phoneBatterySaver ?? this.phoneBatterySaver,
      isSleeping: isSleeping ?? this.isSleeping,
      isCharging: isCharging ?? this.isCharging,
      appInForeground: appInForeground ?? this.appInForeground,
      backgroundMonitoringEnabled:
          backgroundMonitoringEnabled ?? this.backgroundMonitoringEnabled,
      automaticMonitoringEnabled:
          automaticMonitoringEnabled ?? this.automaticMonitoringEnabled,
      manualMode: clearManualMode ? null : (manualMode ?? this.manualMode),
      now: now ?? this.now,
    );
  }
}

class MonitoringDecision {
  const MonitoringDecision({
    required this.mode,
    required this.reason,
    required this.allowHighFrequency,
    required this.allowBackgroundWork,
  });

  final MonitoringMode mode;
  final MonitoringSwitchReason reason;
  final bool allowHighFrequency;
  final bool allowBackgroundWork;
}
