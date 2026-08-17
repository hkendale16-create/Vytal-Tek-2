import '../domain/models/monitoring_mode.dart';

/// Battery- and bandwidth-conscious behavior for each monitoring mode.
class MonitoringPolicy {
  const MonitoringPolicy({
    required this.mode,
    required this.sensorPollInterval,
    required this.uiRefreshInterval,
    required this.syncInterval,
    required this.bleCommunicationAllowed,
    required this.highFrequencySampling,
    required this.ambientMotionLevel,
    required this.expectedBatteryImpact,
  });

  final MonitoringMode mode;

  /// How often adapters may request sensor updates while foregrounded.
  final Duration sensorPollInterval;

  /// Throttle for UI metric animations / live number ticks.
  final Duration uiRefreshInterval;

  /// Periodic sync cadence when connected (foreground).
  final Duration syncInterval;

  final bool bleCommunicationAllowed;
  final bool highFrequencySampling;

  /// 1 micro … 4 3D — used by the motion system in later phases.
  final int ambientMotionLevel;

  final String expectedBatteryImpact;

  static const active = MonitoringPolicy(
    mode: MonitoringMode.active,
    sensorPollInterval: Duration(seconds: 1),
    uiRefreshInterval: Duration(milliseconds: 400),
    syncInterval: Duration(minutes: 2),
    bleCommunicationAllowed: true,
    highFrequencySampling: true,
    ambientMotionLevel: 3,
    expectedBatteryImpact: 'Higher — intended for workouts and live sessions.',
  );

  static const normal = MonitoringPolicy(
    mode: MonitoringMode.normal,
    sensorPollInterval: Duration(seconds: 30),
    uiRefreshInterval: Duration(seconds: 2),
    syncInterval: Duration(minutes: 15),
    bleCommunicationAllowed: true,
    highFrequencySampling: false,
    ambientMotionLevel: 2,
    expectedBatteryImpact: 'Moderate — daily trends and coaching.',
  );

  static const standby = MonitoringPolicy(
    mode: MonitoringMode.standby,
    sensorPollInterval: Duration(minutes: 10),
    uiRefreshInterval: Duration(seconds: 8),
    syncInterval: Duration(hours: 1),
    bleCommunicationAllowed: true,
    highFrequencySampling: false,
    ambientMotionLevel: 1,
    expectedBatteryImpact: 'Lower — reduced sampling and visuals.',
  );

  static MonitoringPolicy forMode(MonitoringMode mode) => switch (mode) {
        MonitoringMode.active => active,
        MonitoringMode.normal => normal,
        MonitoringMode.standby => standby,
      };

  /// Background execution uses a reduced policy even if Active was selected.
  MonitoringPolicy get backgroundSafe {
    if (mode == MonitoringMode.standby) return this;
    return copyWith(
      sensorPollInterval: Duration(
        milliseconds: sensorPollInterval.inMilliseconds * 4,
      ),
      uiRefreshInterval: const Duration(seconds: 30),
      syncInterval: Duration(
        milliseconds: syncInterval.inMilliseconds * 2,
      ),
      highFrequencySampling: false,
      ambientMotionLevel: 1,
    );
  }

  MonitoringPolicy copyWith({
    Duration? sensorPollInterval,
    Duration? uiRefreshInterval,
    Duration? syncInterval,
    bool? bleCommunicationAllowed,
    bool? highFrequencySampling,
    int? ambientMotionLevel,
    String? expectedBatteryImpact,
  }) {
    return MonitoringPolicy(
      mode: mode,
      sensorPollInterval: sensorPollInterval ?? this.sensorPollInterval,
      uiRefreshInterval: uiRefreshInterval ?? this.uiRefreshInterval,
      syncInterval: syncInterval ?? this.syncInterval,
      bleCommunicationAllowed:
          bleCommunicationAllowed ?? this.bleCommunicationAllowed,
      highFrequencySampling:
          highFrequencySampling ?? this.highFrequencySampling,
      ambientMotionLevel: ambientMotionLevel ?? this.ambientMotionLevel,
      expectedBatteryImpact:
          expectedBatteryImpact ?? this.expectedBatteryImpact,
    );
  }
}

extension MonitoringModePolicyX on MonitoringMode {
  MonitoringPolicy get policy => MonitoringPolicy.forMode(this);
}
