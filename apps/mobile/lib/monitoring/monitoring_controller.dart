import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../devices/connection/device_connection_controller.dart';
import '../domain/devices/device_connection_state.dart';
import '../domain/models/monitoring_mode.dart';
import '../domain/models/operating_mode.dart';
import '../state/app_session_controller.dart';
import 'background_monitoring_gate.dart';
import 'monitoring_engine.dart';
import 'monitoring_policy.dart';
import 'monitoring_signals.dart';

class MonitoringRuntimeState {
  const MonitoringRuntimeState({
    required this.mode,
    required this.policy,
    required this.reason,
    required this.signals,
    required this.gate,
    required this.tickCount,
    required this.lastEvaluatedAt,
    this.lastTransitionAt,
  });

  final MonitoringMode mode;
  final MonitoringPolicy policy;
  final MonitoringSwitchReason reason;
  final MonitoringSignals signals;
  final BackgroundMonitoringGate gate;
  final int tickCount;
  final DateTime lastEvaluatedAt;
  final DateTime? lastTransitionAt;

  bool get isHighFrequency => policy.highFrequencySampling;

  MonitoringRuntimeState copyWith({
    MonitoringMode? mode,
    MonitoringPolicy? policy,
    MonitoringSwitchReason? reason,
    MonitoringSignals? signals,
    BackgroundMonitoringGate? gate,
    int? tickCount,
    DateTime? lastEvaluatedAt,
    DateTime? lastTransitionAt,
  }) {
    return MonitoringRuntimeState(
      mode: mode ?? this.mode,
      policy: policy ?? this.policy,
      reason: reason ?? this.reason,
      signals: signals ?? this.signals,
      gate: gate ?? this.gate,
      tickCount: tickCount ?? this.tickCount,
      lastEvaluatedAt: lastEvaluatedAt ?? this.lastEvaluatedAt,
      lastTransitionAt: lastTransitionAt ?? this.lastTransitionAt,
    );
  }
}

final monitoringControllerProvider =
    StateNotifierProvider<MonitoringController, MonitoringRuntimeState>((ref) {
  return MonitoringController(ref);
});

/// Applies [MonitoringEngine] decisions, respects lifecycle, syncs session mode.
class MonitoringController extends StateNotifier<MonitoringRuntimeState>
    with WidgetsBindingObserver {
  MonitoringController(this._ref)
      : super(
          MonitoringRuntimeState(
            mode: MonitoringMode.normal,
            policy: MonitoringPolicy.normal,
            reason: MonitoringSwitchReason.userPreferenceDefault,
            signals: const MonitoringSignals(),
            gate: const BackgroundMonitoringGate(
              userEnabled: false,
              appInForeground: true,
            ),
            tickCount: 0,
            lastEvaluatedAt: DateTime.now().toUtc(),
          ),
        ) {
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  final Ref _ref;
  final _engine = const MonitoringEngine();
  Timer? _evalTimer;
  Timer? _sensorTimer;
  DateTime _lastActivityAt = DateTime.now().toUtc();
  bool _disposed = false;

  /// Honors an explicit user mode pick until a stronger signal arrives.
  MonitoringMode? _stickyManualMode;

  void _bootstrap() {
    final session = _ref.read(appSessionProvider);
    final connection = _ref.read(deviceConnectionProvider);
    _lastActivityAt = DateTime.now().toUtc();

    // Align runtime to persisted session without writing back during init.
    state = state.copyWith(
      mode: session.monitoringMode,
      policy: MonitoringPolicy.forMode(session.monitoringMode),
    );

    final signals = MonitoringSignals(
      automaticMonitoringEnabled: session.automaticMonitoringEnabled,
      backgroundMonitoringEnabled: session.backgroundMonitoringEnabled,
      manualMode: session.monitoringMode,
      wearableBatteryPercent: connection.battery?.value ??
          connection.activeDevice?.batteryPercent,
      appInForeground: true,
    );

    _applySignals(signals);
    _restartEvalTimer();

    _ref.listen(appSessionProvider, (previous, next) {
      if (_disposed) return;
      noteActivity();
      updateSignals(
        automaticMonitoringEnabled: next.automaticMonitoringEnabled,
        backgroundMonitoringEnabled: next.backgroundMonitoringEnabled,
        manualMode: next.monitoringMode,
      );
      // Pairing / unpairing changes how often we should wake the eval loop.
      final wasPaired = previous?.pairedDevice != null;
      final isPaired = next.pairedDevice != null;
      if (wasPaired != isPaired) {
        _restartEvalTimer();
      }
    });

    _ref.listen(deviceConnectionProvider, (previous, next) {
      if (_disposed) return;
      updateSignals(
        wearableBatteryPercent:
            next.battery?.value ?? next.activeDevice?.batteryPercent,
      );
      final wasLinked = previous?.activeDevice != null;
      final isLinked = next.activeDevice != null;
      if (wasLinked != isLinked) {
        _restartSensorTimer();
      }
    });
  }

  void noteActivity() {
    _lastActivityAt = DateTime.now().toUtc();
    updateSignals(inactiveFor: Duration.zero);
  }

  void setWorkoutActive(bool active) {
    noteActivity();
    updateSignals(
      workoutActive: active,
      sustainedMovement: active,
      inactiveFor: Duration.zero,
    );
  }

  void setSleeping(bool sleeping) {
    updateSignals(isSleeping: sleeping);
  }

  void setCharging(bool charging) {
    updateSignals(isCharging: charging);
  }

  void setPhoneBattery({int? percent, bool? batterySaver}) {
    updateSignals(
      phoneBatteryPercent: percent,
      phoneBatterySaver: batterySaver,
      clearPhoneBattery: percent == null && batterySaver == null,
    );
  }

  /// Manual mode selection — always honored; never traps the user in automatic.
  Future<void> selectModeManually(MonitoringMode mode) async {
    noteActivity();
    _stickyManualMode = mode;
    await _ref.read(appSessionProvider.notifier).setMonitoringMode(mode);
    updateSignals(manualMode: mode);
    _applySignals(
      state.signals.copyWith(manualMode: mode),
      forceMode: mode,
      forceReason: MonitoringSwitchReason.manualOverride,
    );
  }

  Future<void> setAutomatic(bool enabled) async {
    await _ref.read(appSessionProvider.notifier).setAutomaticMonitoring(enabled);
    updateSignals(automaticMonitoringEnabled: enabled);
  }

  Future<void> setBackgroundMonitoring(bool enabled) async {
    await _ref
        .read(appSessionProvider.notifier)
        .setBackgroundMonitoring(enabled);
    updateSignals(backgroundMonitoringEnabled: enabled);
  }

  void updateSignals({
    bool? workoutActive,
    bool? sustainedMovement,
    Duration? inactiveFor,
    int? wearableBatteryPercent,
    int? phoneBatteryPercent,
    bool? phoneBatterySaver,
    bool? isSleeping,
    bool? isCharging,
    bool? appInForeground,
    bool? backgroundMonitoringEnabled,
    bool? automaticMonitoringEnabled,
    MonitoringMode? manualMode,
    bool clearWearableBattery = false,
    bool clearPhoneBattery = false,
  }) {
    final next = state.signals.copyWith(
      workoutActive: workoutActive,
      sustainedMovement: sustainedMovement,
      inactiveFor: inactiveFor,
      wearableBatteryPercent: wearableBatteryPercent,
      phoneBatteryPercent: phoneBatteryPercent,
      phoneBatterySaver: phoneBatterySaver,
      isSleeping: isSleeping,
      isCharging: isCharging,
      appInForeground: appInForeground,
      backgroundMonitoringEnabled: backgroundMonitoringEnabled,
      automaticMonitoringEnabled: automaticMonitoringEnabled,
      manualMode: manualMode,
      clearWearableBattery: clearWearableBattery,
      clearPhoneBattery: clearPhoneBattery,
      now: DateTime.now().toUtc(),
    );
    _applySignals(next);
  }

  void _applySignals(
    MonitoringSignals signals, {
    bool force = false,
    MonitoringMode? forceMode,
    MonitoringSwitchReason? forceReason,
  }) {
    if (_disposed) return;

    final inactive = DateTime.now().toUtc().difference(_lastActivityAt);
    final enriched = signals.copyWith(
      inactiveFor:
          signals.inactiveFor > inactive ? signals.inactiveFor : inactive,
      now: DateTime.now().toUtc(),
    );

    final strongSignal = enriched.workoutActive ||
        enriched.sustainedMovement ||
        enriched.isSleeping ||
        enriched.phoneBatterySaver ||
        !enriched.appInForeground ||
        (enriched.wearableBatteryPercent != null &&
            enriched.wearableBatteryPercent! <=
                MonitoringSignals.wearableLowBatteryThreshold &&
            !enriched.isCharging) ||
        (enriched.phoneBatteryPercent != null &&
            enriched.phoneBatteryPercent! <=
                MonitoringSignals.phoneLowBatteryThreshold &&
            !enriched.isCharging);

    if (strongSignal) {
      _stickyManualMode = null;
    }

    final MonitoringDecision decision;
    if (forceMode != null) {
      decision = MonitoringDecision(
        mode: forceMode,
        reason: forceReason ?? MonitoringSwitchReason.manualOverride,
        allowHighFrequency:
            forceMode == MonitoringMode.active && enriched.appInForeground,
        allowBackgroundWork: enriched.backgroundMonitoringEnabled &&
            !enriched.appInForeground,
      );
    } else if (_stickyManualMode != null &&
        enriched.automaticMonitoringEnabled) {
      decision = MonitoringDecision(
        mode: _stickyManualMode!,
        reason: MonitoringSwitchReason.manualOverride,
        allowHighFrequency: _stickyManualMode == MonitoringMode.active &&
            enriched.appInForeground,
        allowBackgroundWork: enriched.backgroundMonitoringEnabled &&
            !enriched.appInForeground,
      );
    } else {
      decision = _engine.decide(current: state.mode, signals: enriched);
    }

    final gate = BackgroundMonitoringGate(
      userEnabled: enriched.backgroundMonitoringEnabled,
      appInForeground: enriched.appInForeground,
    );

    var policy = MonitoringPolicy.forMode(decision.mode);
    if (!enriched.appInForeground) {
      policy = policy.backgroundSafe;
    }
    if (!decision.allowHighFrequency) {
      policy = policy.copyWith(highFrequencySampling: false);
    }
    if (!gate.mayRunForegroundWork && !gate.mayRunBackgroundWork) {
      policy = policy.copyWith(
        bleCommunicationAllowed: false,
        highFrequencySampling: false,
        ambientMotionLevel: 1,
      );
    }

    final modeChanged = decision.mode != state.mode;
    state = state.copyWith(
      mode: decision.mode,
      policy: policy,
      reason: decision.reason,
      signals: enriched,
      gate: gate,
      tickCount: state.tickCount + 1,
      lastEvaluatedAt: DateTime.now().toUtc(),
      lastTransitionAt:
          modeChanged || force ? DateTime.now().toUtc() : state.lastTransitionAt,
    );

    if (modeChanged) {
      // Defer so we never modify AppSession while providers are initializing.
      Future.microtask(() async {
        if (_disposed) return;
        final session = _ref.read(appSessionProvider);
        if (session.monitoringMode == decision.mode) return;
        await _ref
            .read(appSessionProvider.notifier)
            .setMonitoringMode(decision.mode);
      });
      _restartSensorTimer();
    } else if (force) {
      _restartSensorTimer();
    }
  }

  void _restartEvalTimer() {
    _evalTimer?.cancel();
    final session = _ref.read(appSessionProvider);
    final unpaired = session.pairedDevice == null &&
        session.operatingMode != OperatingMode.connected;
    // App-Only / unpaired: evaluate rarely — no BLE work to schedule.
    final period = unpaired
        ? const Duration(minutes: 2)
        : const Duration(seconds: 15);
    _evalTimer = Timer.periodic(period, (_) {
      if (_disposed) return;
      _applySignals(state.signals);
    });
    _restartSensorTimer();
  }

  void _restartSensorTimer() {
    _sensorTimer?.cancel();
    if (!state.policy.bleCommunicationAllowed) return;
    if (!state.gate.mayRunForegroundWork && !state.gate.mayRunBackgroundWork) {
      return;
    }

    final session = _ref.read(appSessionProvider);
    final unpaired = session.pairedDevice == null &&
        !_ref.read(deviceConnectionProvider).state.isLinked;
    // No hardware → no sensor poll ticks (policy intervals stay documented only).
    if (unpaired) return;

    _sensorTimer = Timer.periodic(state.policy.sensorPollInterval, (_) {
      if (_disposed) return;
      // Intent ticks only — live BLE sampling stays gated to explicit sync /
      // workout paths so Active 1s policy does not hammer the radio.
      state = state.copyWith(tickCount: state.tickCount + 1);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      noteActivity();
      updateSignals(appInForeground: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      updateSignals(appInForeground: false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _evalTimer?.cancel();
    _sensorTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
