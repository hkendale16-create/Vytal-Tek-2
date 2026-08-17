import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/domain/models/entitlements.dart';
import 'package:vytal_tek/domain/models/operating_mode.dart';
import 'package:vytal_tek/features/today/today_health_provider.dart';
import 'package:vytal_tek/monitoring/monitoring_policy.dart';
import 'package:vytal_tek/subscription/subscription_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vytal_tek/state/app_session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('App-Only empty snapshot does not invent vitals', () {
    final snap = TodayHealthSnapshot.appOnlyEmpty(
      readinessMessage: 'No wearable readings yet.',
    );
    expect(snap.readinessScore, isNull);
    expect(snap.heartRate.hasValue, isFalse);
    expect(snap.steps, isNull);
    expect(snap.hasWearableContext, isFalse);
  });

  test('Active policy is high-frequency on paper but standby is sparse', () {
    expect(
      MonitoringPolicy.active.sensorPollInterval,
      lessThan(MonitoringPolicy.normal.sensorPollInterval),
    );
    expect(
      MonitoringPolicy.standby.syncInterval.inMinutes,
      greaterThanOrEqualTo(60),
    );
    expect(
      MonitoringPolicy.normal.backgroundSafe.sensorPollInterval.inSeconds,
      greaterThanOrEqualTo(MonitoringPolicy.normal.sensorPollInterval.inSeconds),
    );
  });

  test('subscription refreshAfterLaunch is a no-op for free defaults', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(appSessionProvider).entitlements.tier,
      SubscriptionTier.free,
    );
    expect(
      container.read(appSessionProvider).operatingMode,
      OperatingMode.appOnly,
    );

    final result =
        await container.read(subscriptionControllerProvider).refreshAfterLaunch();
    expect(result, isNull);
  });
}
