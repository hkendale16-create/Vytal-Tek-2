import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/devices/adapters/demo_adapter.dart';
import 'package:vytal_tek/domain/devices/wearable_device.dart';
import 'package:vytal_tek/domain/models/data_provenance.dart';
import 'package:vytal_tek/domain/models/health_metric.dart';
import 'package:vytal_tek/features/today/today_health_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('demo adapter exposes labeled Phase 4 metrics without production provenance',
      () async {
    final adapter = DemoWearableAdapter();
    await adapter.connect(
      knownDevice: const WearableDeviceInfo(
        id: 'demo-1',
        displayName: 'Vytal Ring (Demo)',
        kind: VytalDeviceKind.smartRing,
        adapterId: DemoWearableAdapter.adapterKey,
        isDemo: true,
      ),
    );

    final hr = await adapter.getHeartRate();
    final spo2 = await adapter.getSpo2();
    final sleep = await adapter.getSleep();

    expect(hr.provenance, DataProvenance.demo);
    expect(spo2.provenance, DataProvenance.demo);
    expect(sleep.provenance, DataProvenance.demo);
    expect(hr.hasValue, isTrue);
    expect(spo2.value, 98);
    adapter.dispose();
  });

  test('today health snapshot type keeps readiness nullable when not demo', () {
    // Structural guard: readinessScore is optional and must not default to a fake.
    const snapshot = TodayHealthSnapshot(
      readinessScore: null,
      readinessMessage: 'No wearable readings yet.',
      heartRate: HealthMetricReading(
        key: 'heart_rate',
        displayName: 'Heart Rate',
        provenance: DataProvenance.wearable,
        freshness: ReadingFreshness.unavailable,
      ),
      hrv: HealthMetricReading(
        key: 'hrv',
        displayName: 'HRV',
        provenance: DataProvenance.wearable,
        freshness: ReadingFreshness.notSupported,
      ),
      spo2: HealthMetricReading(
        key: 'spo2',
        displayName: 'SpO₂',
        provenance: DataProvenance.wearable,
        freshness: ReadingFreshness.notSupported,
      ),
      temperature: HealthMetricReading(
        key: 'temperature',
        displayName: 'Temperature',
        provenance: DataProvenance.wearable,
        freshness: ReadingFreshness.notSupported,
      ),
      sleep: HealthMetricReading(
        key: 'sleep_duration',
        displayName: 'Sleep',
        provenance: DataProvenance.wearable,
        freshness: ReadingFreshness.notSupported,
      ),
      battery: HealthMetricReading(
        key: 'wearable_battery',
        displayName: 'Battery',
        provenance: DataProvenance.wearable,
        freshness: ReadingFreshness.unavailable,
      ),
      steps: null,
      calories: null,
      provenance: DataProvenance.wearable,
      hasWearableContext: false,
    );
    expect(snapshot.readinessScore, isNull);
  });
}
