import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/devices/adapters/demo_adapter.dart';
import 'package:vytal_tek/devices/adapters/qring_adapter.dart';
import 'package:vytal_tek/devices/connection/device_connection_exception.dart';
import 'package:vytal_tek/devices/sync/sync_models.dart';
import 'package:vytal_tek/domain/devices/device_connection_state.dart';
import 'package:vytal_tek/domain/devices/wearable_device.dart';
import 'package:vytal_tek/domain/models/data_provenance.dart';
import 'package:vytal_tek/domain/models/health_metric.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('demo adapter scan/pair/sync keeps demo provenance', () async {
    final adapter = DemoWearableAdapter();
    final discovered = await adapter.scan();
    expect(discovered, isNotEmpty);
    expect(discovered.every((d) => d.isDemo), isTrue);

    await adapter.connect(
      knownDevice: WearableDeviceInfo(
        id: 'demo-1',
        displayName: discovered.first.displayName,
        kind: discovered.first.kind,
        adapterId: DemoWearableAdapter.adapterKey,
        isDemo: true,
      ),
    );

    final states = <DeviceConnectionState>[];
    final sub = adapter.connectionState.listen(states.add);
    await adapter.sync();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();

    final battery = await adapter.getBattery();
    final heart = await adapter.getHeartRate();

    expect(battery.provenance, DataProvenance.demo);
    expect(battery.hasValue, isTrue);
    expect(heart.provenance, DataProvenance.demo);
    expect(heart.statusLabel, 'Demo');
    expect(DataProvenance.demo.isProductionSafe, isFalse);

    // Unsupported demo capabilities stay unsupported — not invented.
    final hrv = await adapter.getHrv();
    expect(hrv.freshness, ReadingFreshness.notSupported);
    expect(hrv.hasValue, isFalse);

    adapter.dispose();
  });

  test('qring adapter refuses production pairing without SDK', () async {
    final adapter = QRingWearableAdapter();
    await expectLater(
      adapter.scan(),
      throwsA(
        isA<DeviceConnectionException>().having(
          (e) => e.code,
          'code',
          'sdk_unavailable',
        ),
      ),
    );
    await expectLater(
      adapter.connect(),
      throwsA(isA<DeviceConnectionException>()),
    );
    final heart = await adapter.getHeartRate();
    expect(heart.hasValue, isFalse);
    expect(heart.freshness, ReadingFreshness.notSupported);
    adapter.dispose();
  });

  test('health sample buffer deduplicates identical samples', () {
    final buffer = HealthSampleBuffer();
    final sample = BufferedHealthSample(
      id: 'a',
      deviceId: 'dev',
      metricKey: HealthMetricKeys.heartRate,
      capturedAt: DateTime.utc(2026, 1, 1, 12),
      provenance: DataProvenance.demo,
      payload: {'value': 70},
    );
    expect(buffer.enqueue(sample), 1);
    expect(
      buffer.enqueue(
        BufferedHealthSample(
          id: 'b',
          deviceId: 'dev',
          metricKey: HealthMetricKeys.heartRate,
          capturedAt: DateTime.utc(2026, 1, 1, 12),
          provenance: DataProvenance.demo,
          payload: {'value': 70},
        ),
      ),
      0,
    );
    expect(buffer.length, 1);
  });

  test('connection errors are user-friendly', () {
    expect(
      DeviceConnectionException.deviceNotNearby.userMessage.contains('GATT'),
      isFalse,
    );
    expect(
      DeviceConnectionException.sdkUnavailable.userMessage.toLowerCase(),
      contains('sdk'),
    );
  });
}
