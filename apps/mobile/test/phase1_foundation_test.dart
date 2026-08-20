import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/app.dart';
import 'package:vytal_tek/domain/devices/device_capabilities.dart';
import 'package:vytal_tek/domain/models/data_provenance.dart';
import 'package:vytal_tek/domain/models/entitlements.dart';
import 'package:vytal_tek/domain/models/health_metric.dart';
import 'package:vytal_tek/domain/models/operating_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('free entitlements do not grant advanced AI by default', () {
    expect(
      EntitlementSnapshot.freeDefaults.canUse(EntitlementKeys.aiAdvanced),
      isFalse,
    );
    expect(
      EntitlementSnapshot.freeDefaults.canUse(EntitlementKeys.aiBasic),
      isTrue,
    );
  });

  test('unpaired capabilities hide sensors', () {
    expect(DeviceCapabilities.none.hasAnySensor, isFalse);
    expect(DeviceCapabilities.none.supportsRealtimeHeartRate, isFalse);
  });

  test('missing metrics stay null — no fabricated vitals', () {
    const reading = HealthMetricReading<int>(
      key: HealthMetricKeys.heartRate,
      displayName: 'Heart Rate',
      provenance: DataProvenance.wearable,
      freshness: ReadingFreshness.unavailable,
    );
    expect(reading.hasValue, isFalse);
    expect(DataProvenance.demo.isProductionSafe, isFalse);
  });

  testWidgets('first launch shows device arrival choices', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: VytalApp()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('VYTAL'), findsWidgets);
    expect(find.textContaining('Connect Vytal Device'), findsOneWidget);
    expect(find.textContaining('arriving soon'), findsOneWidget);
    expect(find.textContaining('Without Device'), findsOneWidget);
  });

  testWidgets('completing first launch enters App-Only Today', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: VytalApp()),
    );
    await tester.pumpAndSettle();

    final appOnly = find.textContaining('Without Device');
    await tester.scrollUntilVisible(appOnly, 80);
    await tester.tap(appOnly);
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text(OperatingMode.appOnly.label), findsOneWidget);
  });
}
