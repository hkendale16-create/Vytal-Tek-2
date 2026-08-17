import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/app.dart';
import 'package:vytal_tek/domain/models/operating_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> enterAppOnly(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VytalApp()));
    await tester.pumpAndSettle();
    final appOnly = find.textContaining('without a device');
    await tester.scrollUntilVisible(appOnly, 80);
    await tester.tap(appOnly);
    await tester.pumpAndSettle();
  }

  Future<void> tapNav(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('vytal-hud-dock')),
        matching: find.text(label.toUpperCase()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bottom nav is Today, Vitals, Workouts, Coach, More', (tester) async {
    await enterAppOnly(tester);

    expect(find.byKey(const Key('vytal-hud-dock')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('vytal-hud-dock')),
        matching: find.text('TODAY'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('vytal-hud-dock')),
        matching: find.text('VITALS'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('vytal-hud-dock')),
        matching: find.text('WORKOUTS'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('vytal-hud-dock')),
        matching: find.text('COACH'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('vytal-hud-dock')),
        matching: find.text('MORE'),
      ),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Insights'), findsNothing);
    expect(find.text(OperatingMode.appOnly.label), findsOneWidget);
  });

  testWidgets('More opens existing recovery, sleep, analytics, and settings',
      (tester) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'More');

    expect(find.text('Recovery / Readiness'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Permissions'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Recovery / Readiness'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vytal-hud-dock')), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sleep').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vytal-hud-dock')), findsNothing);
  });

  testWidgets('App-Only Vitals asks to connect instead of blocking the app',
      (tester) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Vitals');

    expect(
      find.text('Connect a Vytal device to begin receiving this measurement.'),
      findsWidgets,
    );
    expect(find.text('HEART RATE'), findsWidgets);
    expect(find.text('WORKOUTS'), findsOneWidget);
  });

  testWidgets('Workouts hub exposes routines, AI, and tools without extra tabs',
      (tester) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Workouts');

    expect(find.text('My Routines'), findsOneWidget);
    expect(find.text('AI Workouts'), findsOneWidget);
    expect(find.text('Workout Tools'), findsOneWidget);
    expect(find.text('Interval timer'), findsOneWidget);
    expect(find.text('Rest timer'), findsOneWidget);
  });

  testWidgets('Coach tab is Ask Vytal with suggested questions', (tester) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Coach');

    expect(find.text('Ask Vytal'), findsOneWidget);
    expect(find.text('How am I doing today?'), findsOneWidget);
    expect(find.text('Build me a workout.'), findsOneWidget);
  });
}
