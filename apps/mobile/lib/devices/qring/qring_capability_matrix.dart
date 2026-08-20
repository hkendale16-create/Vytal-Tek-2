import '../../domain/devices/device_capabilities.dart';

/// Documented QRing / QCBand SDK surface from vendor guides
/// (`sdk_ring_external_access_en`, iOS SDK Development Guide).
///
/// Capabilities are **per-device**. Always read
/// `SetTimeRsp` + `DeviceSupportFunctionRsp` (Android) / equivalent support
/// flags (iOS) after GATT ready — never assume every ring supports every metric.
abstract final class QRingSdkNotes {
  static const androidPackage = 'qring_sdk_1.0.0.60.aar';
  static const iosFramework = 'QCBandSDK.framework';
  static const androidMinSdk = 26;
  static const iosMinVersion = '9.0';

  /// Android BLE scan requires Bluetooth **and** location (runtime).
  static const androidScanRequiresLocation = true;

  /// After `onServiceDiscovered`, request time sync + capability bitmap before
  /// any health queries. Early commands often get no response.
  static const mustQueryCapabilitiesBeforeHealth = true;

  /// Android `BatteryRsp.batteryValue` / `getBatteryValue()` → 0..100.
  static const androidBatteryIsPercent = true;

  /// iOS `readBatterySuccess` → discrete level 0..8 (not percent).
  static const iosBatteryMaxLevel = 8;
}

/// Flags mirrored from Android `SetTimeRsp` + `DeviceSupportFunctionRsp`
/// and iOS measurement/feature APIs. Defaults are false until the live device
/// reports support — do not invent production readings.
class QRingDeviceSupportFlags {
  const QRingDeviceSupportFlags({
    this.supportHeart = false,
    this.supportAppMeasure = false,
    this.supportManualHeart = false,
    this.supportIntervalHeartRate = false,
    this.supportHrv = false,
    this.supportBloodOxygen = false,
    this.supportManualBloodOxygen = false,
    this.supportIntervalBloodOxygen = false,
    this.supportTemperature = false,
    this.supportSkinTemperature = false,
    this.supportIntervalTemperature = false,
    this.supportPressure = false,
    this.supportBloodPressure = false,
    this.supportNewSleepProtocol = false,
    this.supportEcg = false,
    this.supportBlePair = false,
    this.supportFirmwareUpdate = true,
  });

  final bool supportHeart;
  final bool supportAppMeasure;
  final bool supportManualHeart;
  final bool supportIntervalHeartRate;
  final bool supportHrv;
  final bool supportBloodOxygen;
  final bool supportManualBloodOxygen;
  final bool supportIntervalBloodOxygen;
  final bool supportTemperature;
  final bool supportSkinTemperature;
  final bool supportIntervalTemperature;
  final bool supportPressure;
  final bool supportBloodPressure;
  final bool supportNewSleepProtocol;
  final bool supportEcg;
  final bool supportBlePair;

  /// OTA is documented in the Sample (`OtaActivity` / iOS firmware send).
  final bool supportFirmwareUpdate;

  /// Unknown until capability responses are cached.
  static const pending = QRingDeviceSupportFlags();

  /// Maps native MethodChannel capability payloads (Android SetTime +
  /// DeviceSupport / iOS setTime featureList).
  factory QRingDeviceSupportFlags.fromNativeMap(Map<String, dynamic> map) {
    bool flag(String key) => map[key] == true;

    return QRingDeviceSupportFlags(
      supportHeart: flag('supportHeart'),
      supportAppMeasure: flag('supportAppMeasure'),
      supportManualHeart: flag('supportManualHeart'),
      supportIntervalHeartRate: flag('supportIntervalHeartRate'),
      supportHrv: flag('supportHrv'),
      supportBloodOxygen: flag('supportBloodOxygen'),
      supportManualBloodOxygen: flag('supportManualBloodOxygen'),
      supportIntervalBloodOxygen: flag('supportIntervalBloodOxygen'),
      supportTemperature: flag('supportTemperature'),
      supportSkinTemperature: flag('supportSkinTemperature'),
      supportIntervalTemperature: flag('supportIntervalTemperature'),
      supportPressure: flag('supportPressure'),
      supportBloodPressure: flag('supportBloodPressure'),
      supportNewSleepProtocol: flag('supportNewSleepProtocol'),
      supportEcg: flag('supportEcg'),
      supportBlePair: flag('supportBlePair'),
      supportFirmwareUpdate: map['supportFirmwareUpdate'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toNativeMap() => {
        'supportHeart': supportHeart,
        'supportAppMeasure': supportAppMeasure,
        'supportManualHeart': supportManualHeart,
        'supportIntervalHeartRate': supportIntervalHeartRate,
        'supportHrv': supportHrv,
        'supportBloodOxygen': supportBloodOxygen,
        'supportManualBloodOxygen': supportManualBloodOxygen,
        'supportIntervalBloodOxygen': supportIntervalBloodOxygen,
        'supportTemperature': supportTemperature,
        'supportSkinTemperature': supportSkinTemperature,
        'supportIntervalTemperature': supportIntervalTemperature,
        'supportPressure': supportPressure,
        'supportBloodPressure': supportBloodPressure,
        'supportNewSleepProtocol': supportNewSleepProtocol,
        'supportEcg': supportEcg,
        'supportBlePair': supportBlePair,
        'supportFirmwareUpdate': supportFirmwareUpdate,
      };

  /// Metrics the SDK documents as available **when flags allow**.
  /// Steps/sleep are standard health sync paths once a device is connected and
  /// capability sync has completed — pass true from the native bridge then.
  DeviceCapabilities toDeviceCapabilities({
    bool stepsAvailable = false,
    bool sleepAvailable = false,
    bool caloriesAvailable = false,
    bool distanceAvailable = false,
  }) {
    final temperature = supportTemperature ||
        supportSkinTemperature ||
        supportIntervalTemperature;
    final spo2 = supportBloodOxygen ||
        supportManualBloodOxygen ||
        supportIntervalBloodOxygen;
    final heart = supportHeart ||
        supportManualHeart ||
        supportIntervalHeartRate ||
        supportAppMeasure;

    return DeviceCapabilities(
      supportsHeartRate: heart,
      supportsRealtimeHeartRate: supportAppMeasure,
      supportsHrv: supportHrv,
      supportsSpo2: spo2,
      supportsTemperature: temperature,
      supportsSleep: sleepAvailable,
      supportsSleepStages: sleepAvailable,
      supportsRespiratoryRate: false, // not documented as a first-class SDK metric
      supportsSteps: stepsAvailable,
      supportsCalories: caloriesAvailable,
      supportsDistance: distanceAvailable,
      supportsBattery: true,
      supportsFirmwareUpdate: supportFirmwareUpdate,
      supportsWorkoutMonitoring: supportAppMeasure,
    );
  }
}

/// Converts iOS discrete battery level (0..8) to an approximate percent.
///
/// Do not present this as higher precision than the SDK provides.
int? batteryPercentFromIosLevel(int level) {
  if (level < 0 || level > QRingSdkNotes.iosBatteryMaxLevel) return null;
  return ((level / QRingSdkNotes.iosBatteryMaxLevel) * 100).round();
}

/// Sleep stage codes from Android `SleepNewProtoResp.DetailBean.t` / iOS `SLEEPTYPE`.
enum QRingSleepStage {
  unknown,
  awake,
  light,
  deep,
  rem,
  notWorn,
}

QRingSleepStage qringSleepStageFromIos(int type) {
  // iOS SLEEPTYPE: 0 none, 1 awake, 2 light, 3 deep, 4 REM, 5 unweared
  return switch (type) {
    1 => QRingSleepStage.awake,
    2 => QRingSleepStage.light,
    3 => QRingSleepStage.deep,
    4 => QRingSleepStage.rem,
    5 => QRingSleepStage.notWorn,
    _ => QRingSleepStage.unknown,
  };
}

/// Documented Android RealTimeHeartRate command codes from the Sample.
abstract final class QRingRealtimeHeartCommands {
  static const start = 1;
  static const stop = 2;
  static const poll = 3;
  static const recommendedPollInterval = Duration(seconds: 2);
}
