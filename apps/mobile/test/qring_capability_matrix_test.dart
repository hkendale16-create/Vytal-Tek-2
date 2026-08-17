import 'package:flutter_test/flutter_test.dart';
import 'package:vytal_tek/devices/adapters/qring_adapter.dart';
import 'package:vytal_tek/devices/qring/qring_capability_matrix.dart';
import 'package:vytal_tek/domain/models/health_metric.dart';

void main() {
  test('pending QRing flags expose no sensors until device reports support', () {
    const flags = QRingDeviceSupportFlags.pending;
    final caps = flags.toDeviceCapabilities(
      stepsAvailable: false,
      sleepAvailable: false,
      caloriesAvailable: false,
      distanceAvailable: false,
    );
    expect(caps.hasAnySensor, isFalse);
    expect(caps.supportsBattery, isTrue);
    expect(caps.supportsRealtimeHeartRate, isFalse);
  });

  test('documented support flags map to DeviceCapabilities', () {
    const flags = QRingDeviceSupportFlags(
      supportHeart: true,
      supportAppMeasure: true,
      supportHrv: true,
      supportBloodOxygen: true,
      supportTemperature: true,
      supportNewSleepProtocol: true,
    );
    final caps = flags.toDeviceCapabilities(
      stepsAvailable: true,
      sleepAvailable: true,
      caloriesAvailable: true,
      distanceAvailable: true,
    );
    expect(caps.supportsHeartRate, isTrue);
    expect(caps.supportsRealtimeHeartRate, isTrue);
    expect(caps.supportsHrv, isTrue);
    expect(caps.supportsSpo2, isTrue);
    expect(caps.supportsTemperature, isTrue);
    expect(caps.supportsSleep, isTrue);
    expect(caps.supportsSleepStages, isTrue);
    expect(caps.supportsRespiratoryRate, isFalse);
    expect(caps.supportsSteps, isTrue);
  });

  test('realtime HR requires supportAppMeasure, not heart alone', () {
    const flags = QRingDeviceSupportFlags(supportHeart: true);
    expect(flags.toDeviceCapabilities().supportsRealtimeHeartRate, isFalse);

    const withMeasure = QRingDeviceSupportFlags(
      supportHeart: true,
      supportAppMeasure: true,
    );
    expect(withMeasure.toDeviceCapabilities().supportsRealtimeHeartRate, isTrue);
  });

  test('iOS battery levels 0..8 convert without inventing out-of-range values', () {
    expect(batteryPercentFromIosLevel(0), 0);
    expect(batteryPercentFromIosLevel(4), 50);
    expect(batteryPercentFromIosLevel(8), 100);
    expect(batteryPercentFromIosLevel(9), isNull);
    expect(batteryPercentFromIosLevel(-1), isNull);
  });

  test('iOS sleep stage mapping matches SDK SLEEPTYPE', () {
    expect(qringSleepStageFromIos(1), QRingSleepStage.awake);
    expect(qringSleepStageFromIos(2), QRingSleepStage.light);
    expect(qringSleepStageFromIos(3), QRingSleepStage.deep);
    expect(qringSleepStageFromIos(4), QRingSleepStage.rem);
    expect(qringSleepStageFromIos(5), QRingSleepStage.notWorn);
    expect(qringSleepStageFromIos(0), QRingSleepStage.unknown);
  });

  test('qring adapter hides unsupported metrics when flags are pending', () async {
    final adapter = QRingWearableAdapter();
    final hrv = await adapter.getHrv();
    expect(hrv.hasValue, isFalse);
    expect(hrv.freshness, ReadingFreshness.notSupported);
    adapter.dispose();
  });

  test('qring adapter marks supported-but-unsynced metrics unavailable', () async {
    final adapter = QRingWearableAdapter(
      supportFlags: const QRingDeviceSupportFlags(
        supportHeart: true,
        supportAppMeasure: true,
      ),
    );
    final hr = await adapter.getHeartRate();
    expect(hr.hasValue, isFalse);
    expect(hr.freshness, ReadingFreshness.unavailable);
    adapter.dispose();
  });
}
