/// Adaptive monitoring intensity. User can override automatic switching later.
enum MonitoringMode {
  active,
  normal,
  standby,
}

extension MonitoringModeX on MonitoringMode {
  String get label => switch (this) {
        MonitoringMode.active => 'Active',
        MonitoringMode.normal => 'Normal',
        MonitoringMode.standby => 'Standby',
      };

  String get description => switch (this) {
        MonitoringMode.active =>
          'Higher-frequency sampling for workouts and intentional live readings.',
        MonitoringMode.normal =>
          'Balanced daily monitoring for trends, readiness, and coaching.',
        MonitoringMode.standby =>
          'Reduced sampling and visuals to conserve battery.',
      };
}
