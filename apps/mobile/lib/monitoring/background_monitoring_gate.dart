/// Explicit gate for background monitoring work.
///
/// Vytal never attempts prohibited hidden background execution.
/// When background monitoring is off, high-frequency work must stop when the
/// app leaves the foreground. When on, only platform-supported reduced work
/// is allowed — real OS services land with wearable SDK integration.
class BackgroundMonitoringGate {
  const BackgroundMonitoringGate({
    required this.userEnabled,
    required this.appInForeground,
  });

  final bool userEnabled;
  final bool appInForeground;

  bool get mayRunForegroundWork => appInForeground;

  bool get mayRunBackgroundWork => userEnabled && !appInForeground;

  bool get mustSuspendHighFrequency =>
      !appInForeground || !mayRunForegroundWork;

  String get userFacingStatus {
    if (appInForeground) {
      return userEnabled
          ? 'Background monitoring is enabled for when you leave the app.'
          : 'Background monitoring is off. Live updates pause when Vytal is not open.';
    }
    if (!userEnabled) {
      return 'App is in the background and background monitoring is off — monitoring paused.';
    }
    return 'Background monitoring active at a reduced rate. Platform limits still apply.';
  }
}
