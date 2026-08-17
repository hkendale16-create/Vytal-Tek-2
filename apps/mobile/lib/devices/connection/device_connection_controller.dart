import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/devices/device_capabilities.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/health_metric.dart';
import '../../domain/models/operating_mode.dart';
import '../../state/app_session_controller.dart';
import '../adapters/demo_adapter.dart';
import '../adapters/qring_adapter.dart';
import '../adapters/unpaired_adapter.dart';
import '../registry/device_registry.dart';
import '../sync/device_sync_engine.dart';
import '../sync/sync_models.dart';
import 'bluetooth_readiness.dart';
import 'device_connection_exception.dart';
import 'pairing_platform.dart';

class DeviceConnectionSnapshot {
  const DeviceConnectionSnapshot({
    required this.state,
    required this.operatingMode,
    required this.capabilities,
    required this.discovered,
    required this.isScanning,
    required this.isSyncing,
    required this.registry,
    this.activeDevice,
    this.battery,
    this.lastError,
    this.lastSyncResult,
  });

  final DeviceConnectionState state;
  final OperatingMode operatingMode;
  final DeviceCapabilities capabilities;
  final List<DiscoveredWearable> discovered;
  final bool isScanning;
  final bool isSyncing;
  final DeviceRegistry registry;
  final WearableDeviceInfo? activeDevice;
  final HealthMetricReading<int>? battery;
  final DeviceConnectionException? lastError;
  final SyncResult? lastSyncResult;

  static DeviceConnectionSnapshot initial() => const DeviceConnectionSnapshot(
        state: DeviceConnectionState.unpaired,
        operatingMode: OperatingMode.appOnly,
        capabilities: DeviceCapabilities.none,
        discovered: [],
        isScanning: false,
        isSyncing: false,
        registry: DeviceRegistry(),
      );

  DeviceConnectionSnapshot copyWith({
    DeviceConnectionState? state,
    OperatingMode? operatingMode,
    DeviceCapabilities? capabilities,
    List<DiscoveredWearable>? discovered,
    bool? isScanning,
    bool? isSyncing,
    DeviceRegistry? registry,
    WearableDeviceInfo? activeDevice,
    HealthMetricReading<int>? battery,
    DeviceConnectionException? lastError,
    SyncResult? lastSyncResult,
    bool clearError = false,
    bool clearBattery = false,
    bool clearActiveDevice = false,
    bool clearSyncResult = false,
  }) {
    return DeviceConnectionSnapshot(
      state: state ?? this.state,
      operatingMode: operatingMode ?? this.operatingMode,
      capabilities: capabilities ?? this.capabilities,
      discovered: discovered ?? this.discovered,
      isScanning: isScanning ?? this.isScanning,
      isSyncing: isSyncing ?? this.isSyncing,
      registry: registry ?? this.registry,
      activeDevice:
          clearActiveDevice ? null : (activeDevice ?? this.activeDevice),
      battery: clearBattery ? null : (battery ?? this.battery),
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastSyncResult:
          clearSyncResult ? null : (lastSyncResult ?? this.lastSyncResult),
    );
  }
}

final deviceConnectionProvider = StateNotifierProvider<DeviceConnectionController,
    DeviceConnectionSnapshot>((ref) {
  return DeviceConnectionController(ref);
});

class DeviceConnectionController
    extends StateNotifier<DeviceConnectionSnapshot> {
  DeviceConnectionController(this._ref)
      : super(DeviceConnectionSnapshot.initial()) {
    _bootstrap();
  }

  final Ref _ref;
  final _readiness = BluetoothReadinessChecker();
  final _registryStore = DeviceRegistryStore();
  final _syncEngine = DeviceSyncEngine();

  WearableDevice _adapter = UnpairedWearableDevice();
  StreamSubscription<DeviceConnectionState>? _stateSub;
  StreamSubscription<WearableDeviceInfo?>? _infoSub;
  bool _disposed = false;

  void _setState(DeviceConnectionSnapshot next) {
    if (_disposed) return;
    state = next;
  }

  Future<void> _bootstrap() async {
    final registry = await _registryStore.load();
    final session = _ref.read(appSessionProvider);
    _setState(state.copyWith(
      registry: registry,
      activeDevice: session.pairedDevice ?? registry.primary,
      operatingMode: session.operatingMode,
      state: session.connectionState,
    ));

    if (session.pairedDevice != null) {
      await _bindAdapterFor(session.pairedDevice!);
      // Soft reconnect attempt — failures stay user-friendly.
      try {
        await reconnect();
      } catch (_) {
        // Keep saved pairing; show disconnected until user retries.
        if (_disposed) return;
        _setState(state.copyWith(state: DeviceConnectionState.disconnected));
        await _ref.read(appSessionProvider.notifier).setConnectionState(
              DeviceConnectionState.disconnected,
            );
      }
    }
  }

  Future<void> _bindAdapterFor(WearableDeviceInfo device) async {
    await _detachAdapter();
    if (device.isDemo || device.adapterId == DemoWearableAdapter.adapterKey) {
      _adapter = DemoWearableAdapter(knownDevice: device);
    } else if (device.adapterId == 'qring') {
      _adapter = QRingWearableAdapter(knownDevice: device);
    } else {
      _adapter = UnpairedWearableDevice();
    }
    _stateSub = _adapter.connectionState.listen((value) {
      if (value == DeviceConnectionState.disconnected &&
          state.state == DeviceConnectionState.connected) {
        _setState(state.copyWith(state: DeviceConnectionState.disconnected));
        return;
      }
      _setState(state.copyWith(state: value));
    });
    _infoSub = _adapter.deviceInfo.listen((info) {
      if (info == null) return;
      _setState(state.copyWith(
        activeDevice: info,
        capabilities: _adapter.capabilities,
        registry: state.registry.upsert(info),
      ));
    });
    _setState(state.copyWith(capabilities: _adapter.capabilities));
  }

  Future<void> _detachAdapter() async {
    await _stateSub?.cancel();
    await _infoSub?.cancel();
    _stateSub = null;
    _infoSub = null;
    final current = _adapter;
    if (current is UnpairedWearableDevice) current.dispose();
    if (current is DemoWearableAdapter) current.dispose();
    if (current is QRingWearableAdapter) current.dispose();
    _adapter = UnpairedWearableDevice();
  }

  WearableDevice get adapter => _adapter;

  Future<void> scanForDevices() async {
    _setState(state.copyWith(
      clearError: true,
      isScanning: true,
      discovered: [],
      state: DeviceConnectionState.scanning,
    ));
    final session = _ref.read(appSessionProvider);

    if (!session.demoModeEnabled && !PairingPlatform.blePairingSupported) {
      final error = DeviceConnectionException(
        code: 'bluetooth_unsupported',
        userMessage:
            PairingPlatform.limitationMessage(demoModeEnabled: false),
        canRetry: false,
      );
      _setState(state.copyWith(
        isScanning: false,
        lastError: error,
        state: DeviceConnectionState.error,
      ));
      throw error;
    }

    final readiness = await _readiness.check(requestIfNeeded: true);
    if (!readiness.canScan && !session.demoModeEnabled) {
      final error = readiness.asException ?? DeviceConnectionException.permissionDenied;
      _setState(state.copyWith(
        isScanning: false,
        lastError: error,
        state: DeviceConnectionState.error,
      ));
      throw error;
    }

    try {
      final scanner = session.demoModeEnabled
          ? DemoWearableAdapter()
          : QRingWearableAdapter();
      final found = await scanner.scan();
      _setState(state.copyWith(
        isScanning: false,
        discovered: found,
        state: found.isEmpty
            ? DeviceConnectionState.disconnected
            : DeviceConnectionState.disconnected,
        lastError: found.isEmpty && !session.demoModeEnabled
            ? const DeviceConnectionException(
                code: 'no_devices',
                userMessage:
                    'No devices found. Keep your Vytal ring nearby, charged, and Bluetooth on, then scan again.',
              )
            : null,
        clearError: found.isNotEmpty,
      ));
    } on DeviceConnectionException catch (error) {
      _setState(state.copyWith(
        isScanning: false,
        lastError: error,
        state: DeviceConnectionState.error,
      ));
      rethrow;
    } catch (error) {
      final wrapped = DeviceConnectionException(
        code: 'scan_failed',
        userMessage:
            'We couldn’t find nearby Vytal devices. Check Bluetooth and try again.',
        technicalDetail: error.toString(),
      );
      _setState(state.copyWith(
        isScanning: false,
        lastError: wrapped,
        state: DeviceConnectionState.error,
      ));
      throw wrapped;
    }
  }

  Future<void> pairDiscovered(DiscoveredWearable discovered) async {
    final session = _ref.read(appSessionProvider);
    if (discovered.isDemo && !session.demoModeEnabled) {
      throw DeviceConnectionException.demoRequired;
    }
    if (state.activeDevice != null &&
        state.state == DeviceConnectionState.connected) {
      throw DeviceConnectionException.alreadyConnected;
    }

    _setState(state.copyWith(
      clearError: true,
      state: DeviceConnectionState.connecting,
    ));

    final info = WearableDeviceInfo(
      id: const Uuid().v4(),
      displayName: discovered.displayName,
      kind: discovered.kind,
      adapterId: discovered.adapterId,
      model: discovered.displayName,
      bluetoothId: discovered.discoveryId,
      isDemo: discovered.isDemo,
      firmwareVersion: discovered.isDemo ? '0.0.0-demo' : null,
    );

    await _bindAdapterFor(info);

    try {
      await _adapter.connect(knownDevice: info);
      final battery = await _adapter.getBattery();
      final connected = info.copyWith(batteryPercent: battery.value);

      final registry = state.registry.upsert(connected);
      await _registryStore.save(registry);

      _setState(state.copyWith(
        activeDevice: connected,
        registry: registry,
        battery: battery,
        operatingMode: OperatingMode.connected,
        state: DeviceConnectionState.connected,
        capabilities: _adapter.capabilities,
        discovered: const [],
      ));

      await _ref.read(appSessionProvider.notifier).markDevicePaired(connected);
    } on DeviceConnectionException catch (error) {
      _setState(state.copyWith(
        lastError: error,
        state: DeviceConnectionState.error,
      ));
      rethrow;
    }
  }

  Future<void> reconnect() async {
    final device = state.activeDevice;
    if (device == null) {
      throw DeviceConnectionException.deviceNotNearby;
    }
    _setState(state.copyWith(
      clearError: true,
      state: DeviceConnectionState.reconnecting,
    ));
    await _bindAdapterFor(device);
    try {
      await _adapter.connect(knownDevice: device);
      final battery = await _adapter.getBattery();
      _setState(state.copyWith(
        state: DeviceConnectionState.connected,
        battery: battery,
        operatingMode: OperatingMode.connected,
      ));
      await _ref.read(appSessionProvider.notifier).setConnectionState(
            DeviceConnectionState.connected,
          );
    } on DeviceConnectionException catch (error) {
      _setState(state.copyWith(
        state: DeviceConnectionState.disconnected,
        lastError: error,
      ));
      await _ref.read(appSessionProvider.notifier).setConnectionState(
            DeviceConnectionState.disconnected,
          );
      rethrow;
    }
  }

  Future<void> disconnect({bool remove = false}) async {
    try {
      await _adapter.disconnect();
    } catch (_) {
      // Still clear local state.
    }
    if (remove) {
      final id = state.activeDevice?.id;
      var registry = state.registry;
      if (id != null) registry = registry.remove(id);
      await _registryStore.save(registry);
      await _detachAdapter();
      _setState(state.copyWith(
        registry: registry,
        clearActiveDevice: true,
        clearBattery: true,
        clearSyncResult: true,
        operatingMode: OperatingMode.appOnly,
        state: DeviceConnectionState.unpaired,
        capabilities: DeviceCapabilities.none,
        discovered: const [],
      ));
      await _ref.read(appSessionProvider.notifier).disconnectDevice(remove: true);
    } else {
      _setState(state.copyWith(state: DeviceConnectionState.disconnected));
      await _ref.read(appSessionProvider.notifier).setConnectionState(
            DeviceConnectionState.disconnected,
          );
    }
  }

  Future<void> renameActiveDevice(String name) async {
    final device = state.activeDevice;
    if (device == null || name.trim().isEmpty) return;
    final updated = device.copyWith(displayName: name.trim());
    final registry = state.registry.upsert(updated);
    await _registryStore.save(registry);
    _setState(state.copyWith(activeDevice: updated, registry: registry));
    await _ref.read(appSessionProvider.notifier).updatePairedDevice(updated);
  }

  Future<SyncResult> syncNow() async {
    final device = state.activeDevice;
    if (device == null) {
      throw DeviceConnectionException.deviceNotNearby;
    }
    _setState(state.copyWith(isSyncing: true, clearError: true));
    try {
      if (state.state != DeviceConnectionState.connected) {
        await reconnect();
      }
      final result = await _syncEngine.syncDevice(_adapter, deviceId: device.id);
      final battery = await _adapter.getBattery();
      final updated = device.copyWith(
        lastSyncAt: result.finishedAt,
        batteryPercent: battery.value ?? device.batteryPercent,
      );
      final registry = state.registry.upsert(updated);
      await _registryStore.save(registry);
      _setState(state.copyWith(
        isSyncing: false,
        activeDevice: updated,
        registry: registry,
        battery: battery,
        lastSyncResult: result,
        state: DeviceConnectionState.connected,
      ));
      await _ref.read(appSessionProvider.notifier).updatePairedDevice(updated);
      if (!result.ok) {
        if (result.errorCode == DeviceConnectionException.sdkUnavailable.code) {
          throw DeviceConnectionException.sdkUnavailable;
        }
        throw DeviceConnectionException(
          code: result.errorCode ?? 'sync_failed',
          userMessage: result.message ??
              'We couldn’t finish syncing. Keep the device nearby and try again.',
        );
      }
      return result;
    } on DeviceConnectionException catch (error) {
      _setState(state.copyWith(isSyncing: false, lastError: error));
      rethrow;
    } catch (error) {
      final wrapped = DeviceConnectionException(
        code: 'sync_failed',
        userMessage:
            'We couldn’t finish syncing. Keep the device nearby and try again.',
        technicalDetail: error.toString(),
      );
      _setState(state.copyWith(isSyncing: false, lastError: wrapped));
      throw wrapped;
    }
  }

  void clearError() {
    _setState(state.copyWith(clearError: true));
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_detachAdapter());
    super.dispose();
  }
}
