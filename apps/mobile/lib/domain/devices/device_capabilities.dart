/// Capability flags advertised by a wearable adapter.
///
/// UI must hide or adapt metrics that are false. Do not show fake placeholders.
class DeviceCapabilities {
  const DeviceCapabilities({
    this.supportsHeartRate = false,
    this.supportsRealtimeHeartRate = false,
    this.supportsHrv = false,
    this.supportsSpo2 = false,
    this.supportsTemperature = false,
    this.supportsSleep = false,
    this.supportsSleepStages = false,
    this.supportsRespiratoryRate = false,
    this.supportsSteps = false,
    this.supportsCalories = false,
    this.supportsDistance = false,
    this.supportsBattery = false,
    this.supportsFirmwareUpdate = false,
    this.supportsWorkoutMonitoring = false,
  });

  final bool supportsHeartRate;
  final bool supportsRealtimeHeartRate;
  final bool supportsHrv;
  final bool supportsSpo2;
  final bool supportsTemperature;
  final bool supportsSleep;
  final bool supportsSleepStages;
  final bool supportsRespiratoryRate;
  final bool supportsSteps;
  final bool supportsCalories;
  final bool supportsDistance;
  final bool supportsBattery;
  final bool supportsFirmwareUpdate;
  final bool supportsWorkoutMonitoring;

  /// Empty capability set for App-Only mode / unpaired state.
  static const none = DeviceCapabilities();

  /// Unknown until the real QRing (or other) SDK adapter reports flags.
  static const unknownPendingSdk = DeviceCapabilities();

  bool get hasAnySensor =>
      supportsHeartRate ||
      supportsHrv ||
      supportsSpo2 ||
      supportsTemperature ||
      supportsSleep ||
      supportsSteps;
}
