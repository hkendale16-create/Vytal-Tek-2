import 'package:flutter_test/flutter_test.dart';
import 'package:vytal_tek/domain/models/monitoring_mode.dart';
import 'package:vytal_tek/monitoring/background_monitoring_gate.dart';
import 'package:vytal_tek/monitoring/monitoring_engine.dart';
import 'package:vytal_tek/monitoring/monitoring_policy.dart';
import 'package:vytal_tek/monitoring/monitoring_signals.dart';

void main() {
  const engine = MonitoringEngine();

  test('manual override wins when automatic mode is off', () {
    final decision = engine.decide(
      current: MonitoringMode.normal,
      signals: const MonitoringSignals(
        automaticMonitoringEnabled: false,
        manualMode: MonitoringMode.standby,
      ),
    );
    expect(decision.mode, MonitoringMode.standby);
    expect(decision.reason, MonitoringSwitchReason.manualOverride);
  });

  test('workout moves to Active', () {
    final decision = engine.decide(
      current: MonitoringMode.normal,
      signals: const MonitoringSignals(workoutActive: true),
    );
    expect(decision.mode, MonitoringMode.active);
    expect(decision.allowHighFrequency, isTrue);
  });

  test('workout end returns to Normal from Active', () {
    final decision = engine.decide(
      current: MonitoringMode.active,
      signals: const MonitoringSignals(workoutActive: false),
    );
    expect(decision.mode, MonitoringMode.normal);
    expect(decision.reason, MonitoringSwitchReason.workoutEnded);
  });

  test('long inactivity enters Standby', () {
    final decision = engine.decide(
      current: MonitoringMode.normal,
      signals: const MonitoringSignals(
        inactiveFor: Duration(minutes: 50),
      ),
    );
    expect(decision.mode, MonitoringMode.standby);
    expect(decision.reason, MonitoringSwitchReason.sustainedInactivity);
  });

  test('wearable low battery prefers Standby', () {
    final decision = engine.decide(
      current: MonitoringMode.normal,
      signals: const MonitoringSignals(wearableBatteryPercent: 18),
    );
    expect(decision.mode, MonitoringMode.standby);
    expect(decision.reason, MonitoringSwitchReason.wearableLowBattery);
  });

  test('background without permission suspends to Standby', () {
    final decision = engine.decide(
      current: MonitoringMode.active,
      signals: const MonitoringSignals(
        appInForeground: false,
        backgroundMonitoringEnabled: false,
        workoutActive: true,
      ),
    );
    expect(decision.mode, MonitoringMode.standby);
    expect(decision.allowHighFrequency, isFalse);
    expect(decision.allowBackgroundWork, isFalse);
  });

  test('background with permission reduces Active workout to Normal', () {
    final decision = engine.decide(
      current: MonitoringMode.active,
      signals: const MonitoringSignals(
        appInForeground: false,
        backgroundMonitoringEnabled: true,
        workoutActive: true,
      ),
    );
    expect(decision.mode, MonitoringMode.normal);
    expect(decision.allowHighFrequency, isFalse);
    expect(decision.allowBackgroundWork, isTrue);
  });

  test('sleep prefers Standby', () {
    final decision = engine.decide(
      current: MonitoringMode.normal,
      signals: const MonitoringSignals(isSleeping: true),
    );
    expect(decision.mode, MonitoringMode.standby);
    expect(decision.reason, MonitoringSwitchReason.sleeping);
  });

  test('active policy is higher frequency than standby', () {
    expect(
      MonitoringPolicy.active.sensorPollInterval <
          MonitoringPolicy.standby.sensorPollInterval,
      isTrue,
    );
    expect(MonitoringPolicy.active.highFrequencySampling, isTrue);
    expect(MonitoringPolicy.standby.highFrequencySampling, isFalse);
    expect(
      MonitoringPolicy.active.backgroundSafe.highFrequencySampling,
      isFalse,
    );
  });

  test('background gate blocks work when disabled', () {
    const gate = BackgroundMonitoringGate(
      userEnabled: false,
      appInForeground: false,
    );
    expect(gate.mayRunBackgroundWork, isFalse);
    expect(gate.mustSuspendHighFrequency, isTrue);
  });
}
