import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vytal_tek/devices/adapters/qring_adapter.dart';
import 'package:vytal_tek/devices/qring/qring_capability_matrix.dart';
import 'package:vytal_tek/devices/qring/qring_native_api.dart';
import 'package:vytal_tek/domain/devices/device_connection_state.dart';
import 'package:vytal_tek/domain/devices/wearable_device.dart';
import 'package:vytal_tek/domain/models/data_provenance.dart';
import 'package:vytal_tek/domain/models/health_metric.dart';

class _FakeQRingNativeApi implements QRingNativeApi {
  _FakeQRingNativeApi({
    this.available = true,
    this.flags = const QRingDeviceSupportFlags(
      supportHeart: true,
      supportHrv: true,
      supportBloodOxygen: true,
      supportTemperature: true,
      supportNewSleepProtocol: true,
      supportAppMeasure: true,
    ),
    this.snapshot = const QRingHealthSnapshot(
      battery: QRingBatteryReading(percent: 81, charging: false),
      heartRateBpm: 72,
      hrvMs: 45,
      spo2Percent: 98,
      temperatureCelsius: 36.4,
      sleepMinutes: 420,
      steps: 3200,
      calories: 180,
      distanceMeters: 2400,
      sleepAvailable: true,
      stepsAvailable: true,
    ),
  });

  final bool available;
  final QRingDeviceSupportFlags flags;
  final QRingHealthSnapshot snapshot;
  final _scan = StreamController<QRingScanResult>.broadcast();
  bool connected = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> initialize() async {}

  @override
  Stream<QRingScanResult> startScan({
    Duration timeout = const Duration(seconds: 12),
  }) {
    scheduleMicrotask(() {
      _scan.add(
        const QRingScanResult(deviceId: 'AA:BB:CC:DD:EE:FF', name: 'QRing-Test', rssi: -55),
      );
    });
    return _scan.stream;
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<QRingNativeConnectionResult> connect(String deviceId) async {
    connected = true;
    return QRingNativeConnectionResult(
      deviceId: deviceId,
      name: 'QRing-Test',
      flags: flags,
      firmwareVersion: '1.0.0-test',
    );
  }

  @override
  Future<void> disconnect({bool unbind = false}) async {
    connected = false;
  }

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<QRingDeviceSupportFlags> getCapabilities() async => flags;

  @override
  Future<QRingBatteryReading?> readBattery() async => snapshot.battery;

  @override
  Future<QRingHealthSnapshot> syncHealth() async => snapshot;

  @override
  Future<void> startWorkoutMonitoring() async {}

  @override
  Future<void> stopWorkoutMonitoring() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('qring adapter uses native bridge for scan/connect/sync without inventing extras',
      () async {
    final fake = _FakeQRingNativeApi();
    final adapter = QRingWearableAdapter(nativeApi: fake);

    final found = await adapter.scan(timeout: const Duration(milliseconds: 50));
    expect(found, isNotEmpty);
    expect(found.first.adapterId, 'qring');
    expect(found.first.isDemo, isFalse);

    await adapter.connect(
      knownDevice: WearableDeviceInfo(
        id: 'pair-1',
        displayName: found.first.displayName,
        kind: found.first.kind,
        adapterId: 'qring',
        bluetoothId: found.first.discoveryId,
      ),
    );

    expect(adapter.capabilities.supportsHeartRate, isTrue);
    expect(adapter.capabilities.supportsRespiratoryRate, isFalse);

    await adapter.sync();
    final heart = await adapter.getHeartRate();
    final battery = await adapter.getBattery();
    final sleep = await adapter.getSleep();

    expect(heart.provenance, DataProvenance.wearable);
    expect(heart.value, 72);
    expect(battery.value, 81);
    expect(sleep.value, const Duration(minutes: 420));
    expect(heart.statusLabel, isNot(equals('Demo')));

    adapter.dispose();
  });

  test('unsupported flags stay notSupported even when fake has values', () async {
    final fake = _FakeQRingNativeApi(
      flags: const QRingDeviceSupportFlags(), // all false
      snapshot: const QRingHealthSnapshot(heartRateBpm: 99),
    );
    final adapter = QRingWearableAdapter(nativeApi: fake);
    await adapter.connect(
      knownDevice: const WearableDeviceInfo(
        id: 'x',
        displayName: 'QRing',
        kind: VytalDeviceKind.smartRing,
        adapterId: 'qring',
        bluetoothId: 'AA:BB',
      ),
    );
    await adapter.sync();
    final heart = await adapter.getHeartRate();
    expect(heart.hasValue, isFalse);
    expect(heart.freshness, ReadingFreshness.notSupported);
    adapter.dispose();
  });

  test('unavailable native bridge still refuses production pairing', () async {
    final adapter = QRingWearableAdapter(
      nativeApi: _FakeQRingNativeApi(available: false),
    );
    await expectLater(adapter.scan(), throwsA(isA<Exception>()));
    adapter.dispose();
  });

  test('connection state moves pairing → connected on success', () async {
    final fake = _FakeQRingNativeApi();
    final adapter = QRingWearableAdapter(nativeApi: fake);
    final states = <DeviceConnectionState>[];
    final sub = adapter.connectionState.listen(states.add);
    await adapter.connect(
      knownDevice: const WearableDeviceInfo(
        id: 'x',
        displayName: 'QRing',
        kind: VytalDeviceKind.smartRing,
        adapterId: 'qring',
        bluetoothId: 'AA:BB',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    expect(states, contains(DeviceConnectionState.pairing));
    expect(states, contains(DeviceConnectionState.connected));
    adapter.dispose();
  });
}
