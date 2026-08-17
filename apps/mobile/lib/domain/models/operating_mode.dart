/// How the app is currently being used relative to hardware.
enum OperatingMode {
  /// Valuable app experience before a wearable is paired.
  appOnly,

  /// Wearable is paired; sensor data may enrich the profile.
  connected,
}

extension OperatingModeX on OperatingMode {
  String get label => switch (this) {
        OperatingMode.appOnly => 'App-Only',
        OperatingMode.connected => 'Connected',
      };

  String get description => switch (this) {
        OperatingMode.appOnly =>
          'Using Vytal without a paired wearable. Manual entries and AI planning remain available.',
        OperatingMode.connected =>
          'A Vytal wearable is paired. Live and synced readings can enrich your profile.',
      };
}
