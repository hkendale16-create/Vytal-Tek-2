import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/devices/device_adapters.dart';
import '../../domain/devices/device_capabilities.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/monitoring_mode.dart';
import '../../domain/models/operating_mode.dart';
import '../../domain/models/personal_profile.dart';

const _sessionKey = 'vytal.app_session.v1';

class AppSession {
  const AppSession({
    required this.hasCompletedFirstLaunch,
    required this.deviceArrivalChoice,
    required this.operatingMode,
    required this.monitoringMode,
    required this.automaticMonitoringEnabled,
    required this.backgroundMonitoringEnabled,
    required this.demoModeEnabled,
    required this.profile,
    required this.entitlements,
    required this.baselineState,
    required this.connectionState,
    this.pairedDevice,
  });

  final bool hasCompletedFirstLaunch;
  final DeviceArrivalChoice deviceArrivalChoice;
  final OperatingMode operatingMode;
  final MonitoringMode monitoringMode;
  final bool automaticMonitoringEnabled;
  final bool backgroundMonitoringEnabled;

  /// Demo mode may show simulated visuals — never labeled as real sensor data.
  final bool demoModeEnabled;
  final PersonalProfile profile;
  final EntitlementSnapshot entitlements;
  final BaselineCalibrationState baselineState;
  final DeviceConnectionState connectionState;
  final WearableDeviceInfo? pairedDevice;

  DeviceCapabilities get capabilities =>
      pairedDevice == null ? DeviceCapabilities.none : DeviceCapabilities.unknownPendingSdk;

  AppSession copyWith({
    bool? hasCompletedFirstLaunch,
    DeviceArrivalChoice? deviceArrivalChoice,
    OperatingMode? operatingMode,
    MonitoringMode? monitoringMode,
    bool? automaticMonitoringEnabled,
    bool? backgroundMonitoringEnabled,
    bool? demoModeEnabled,
    PersonalProfile? profile,
    EntitlementSnapshot? entitlements,
    BaselineCalibrationState? baselineState,
    DeviceConnectionState? connectionState,
    WearableDeviceInfo? pairedDevice,
    bool clearPairedDevice = false,
  }) {
    return AppSession(
      hasCompletedFirstLaunch:
          hasCompletedFirstLaunch ?? this.hasCompletedFirstLaunch,
      deviceArrivalChoice: deviceArrivalChoice ?? this.deviceArrivalChoice,
      operatingMode: operatingMode ?? this.operatingMode,
      monitoringMode: monitoringMode ?? this.monitoringMode,
      automaticMonitoringEnabled:
          automaticMonitoringEnabled ?? this.automaticMonitoringEnabled,
      backgroundMonitoringEnabled:
          backgroundMonitoringEnabled ?? this.backgroundMonitoringEnabled,
      demoModeEnabled: demoModeEnabled ?? this.demoModeEnabled,
      profile: profile ?? this.profile,
      entitlements: entitlements ?? this.entitlements,
      baselineState: baselineState ?? this.baselineState,
      connectionState: connectionState ?? this.connectionState,
      pairedDevice:
          clearPairedDevice ? null : (pairedDevice ?? this.pairedDevice),
    );
  }

  static AppSession initial() => const AppSession(
        hasCompletedFirstLaunch: false,
        deviceArrivalChoice: DeviceArrivalChoice.undecided,
        operatingMode: OperatingMode.appOnly,
        monitoringMode: MonitoringMode.normal,
        automaticMonitoringEnabled: true,
        backgroundMonitoringEnabled: false,
        demoModeEnabled: false,
        profile: PersonalProfile(),
        entitlements: EntitlementSnapshot.freeDefaults,
        baselineState: BaselineCalibrationState.notStarted,
        connectionState: DeviceConnectionState.unpaired,
      );

  Map<String, dynamic> toJson() => {
        'hasCompletedFirstLaunch': hasCompletedFirstLaunch,
        'deviceArrivalChoice': deviceArrivalChoice.name,
        'operatingMode': operatingMode.name,
        'monitoringMode': monitoringMode.name,
        'automaticMonitoringEnabled': automaticMonitoringEnabled,
        'backgroundMonitoringEnabled': backgroundMonitoringEnabled,
        'demoModeEnabled': demoModeEnabled,
        'profile': profile.toJson(),
        'baselineState': baselineState.name,
        'connectionState': connectionState.name,
        'pairedDevice': pairedDevice == null
            ? null
            : {
                'id': pairedDevice!.id,
                'displayName': pairedDevice!.displayName,
                'kind': pairedDevice!.kind.name,
                'model': pairedDevice!.model,
                'firmwareVersion': pairedDevice!.firmwareVersion,
                'batteryPercent': pairedDevice!.batteryPercent,
                'lastSyncAt': pairedDevice!.lastSyncAt?.toIso8601String(),
              },
      };

  factory AppSession.fromJson(Map<String, dynamic> json) {
    final paired = json['pairedDevice'] as Map<String, dynamic>?;
    return AppSession(
      hasCompletedFirstLaunch: json['hasCompletedFirstLaunch'] as bool? ?? false,
      deviceArrivalChoice: DeviceArrivalChoice.values.firstWhere(
        (e) => e.name == json['deviceArrivalChoice'],
        orElse: () => DeviceArrivalChoice.undecided,
      ),
      operatingMode: OperatingMode.values.firstWhere(
        (e) => e.name == json['operatingMode'],
        orElse: () => OperatingMode.appOnly,
      ),
      monitoringMode: MonitoringMode.values.firstWhere(
        (e) => e.name == json['monitoringMode'],
        orElse: () => MonitoringMode.normal,
      ),
      automaticMonitoringEnabled:
          json['automaticMonitoringEnabled'] as bool? ?? true,
      backgroundMonitoringEnabled:
          json['backgroundMonitoringEnabled'] as bool? ?? false,
      demoModeEnabled: json['demoModeEnabled'] as bool? ?? false,
      profile: json['profile'] is Map<String, dynamic>
          ? PersonalProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : const PersonalProfile(),
      entitlements: EntitlementSnapshot.freeDefaults,
      baselineState: BaselineCalibrationState.values.firstWhere(
        (e) => e.name == json['baselineState'],
        orElse: () => BaselineCalibrationState.notStarted,
      ),
      connectionState: DeviceConnectionState.values.firstWhere(
        (e) => e.name == json['connectionState'],
        orElse: () => DeviceConnectionState.unpaired,
      ),
      pairedDevice: paired == null
          ? null
          : WearableDeviceInfo(
              id: paired['id'] as String,
              displayName: paired['displayName'] as String? ?? 'Vytal Device',
              kind: VytalDeviceKind.values.firstWhere(
                (e) => e.name == paired['kind'],
                orElse: () => VytalDeviceKind.unknown,
              ),
              model: paired['model'] as String?,
              firmwareVersion: paired['firmwareVersion'] as String?,
              batteryPercent: paired['batteryPercent'] as int?,
              lastSyncAt: paired['lastSyncAt'] == null
                  ? null
                  : DateTime.tryParse(paired['lastSyncAt'] as String),
            ),
    );
  }
}

enum DeviceArrivalChoice {
  undecided,
  alreadyHaveDevice,
  deviceOnTheWay,
  appWithoutDevice,
}

extension DeviceArrivalChoiceX on DeviceArrivalChoice {
  String get label => switch (this) {
        DeviceArrivalChoice.undecided => 'Not chosen yet',
        DeviceArrivalChoice.alreadyHaveDevice => 'I already have my device',
        DeviceArrivalChoice.deviceOnTheWay => 'My device is on the way',
        DeviceArrivalChoice.appWithoutDevice =>
          'I’m using the app without a device',
      };
}

final appSessionProvider =
    StateNotifierProvider<AppSessionController, AppSession>((ref) {
  return AppSessionController()..restore();
});

final wearableDeviceProvider = Provider<WearableDevice>((ref) {
  final session = ref.watch(appSessionProvider);
  if (session.operatingMode == OperatingMode.connected &&
      session.pairedDevice != null) {
    // Phase 2 will swap in the real QRing adapter instance.
    return QRingWearableAdapter();
  }
  return UnpairedWearableDevice();
});

class AppSessionController extends StateNotifier<AppSession> {
  AppSessionController() : super(AppSession.initial());

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null) return;
    try {
      state = AppSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupted local session — keep defaults without crashing.
      state = AppSession.initial();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(state.toJson()));
  }

  Future<void> completeFirstLaunch(DeviceArrivalChoice choice) async {
    final mode = choice == DeviceArrivalChoice.alreadyHaveDevice
        ? OperatingMode.appOnly // still app-only until actually paired
        : OperatingMode.appOnly;
    state = state.copyWith(
      hasCompletedFirstLaunch: true,
      deviceArrivalChoice: choice,
      operatingMode: mode,
    );
    await _persist();
  }

  Future<void> updateProfile(PersonalProfile profile) async {
    state = state.copyWith(profile: profile);
    await _persist();
  }

  Future<void> setMonitoringMode(MonitoringMode mode) async {
    state = state.copyWith(monitoringMode: mode);
    await _persist();
  }

  Future<void> setAutomaticMonitoring(bool enabled) async {
    state = state.copyWith(automaticMonitoringEnabled: enabled);
    await _persist();
  }

  Future<void> setBackgroundMonitoring(bool enabled) async {
    state = state.copyWith(backgroundMonitoringEnabled: enabled);
    await _persist();
  }

  Future<void> setDemoMode(bool enabled) async {
    state = state.copyWith(demoModeEnabled: enabled);
    await _persist();
  }

  /// Transition to Connected Mode without resetting profile/history.
  Future<void> markDevicePaired(WearableDeviceInfo device) async {
    state = state.copyWith(
      pairedDevice: device,
      operatingMode: OperatingMode.connected,
      connectionState: DeviceConnectionState.connected,
      baselineState: BaselineCalibrationState.learning,
    );
    await _persist();
  }

  Future<void> disconnectDevice({bool remove = false}) async {
    state = state.copyWith(
      operatingMode: OperatingMode.appOnly,
      connectionState: DeviceConnectionState.unpaired,
      baselineState: BaselineCalibrationState.notStarted,
      clearPairedDevice: remove,
      pairedDevice: remove ? null : state.pairedDevice,
    );
    await _persist();
  }
}
