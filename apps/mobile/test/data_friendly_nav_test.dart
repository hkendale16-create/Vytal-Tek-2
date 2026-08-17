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
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bottom nav is Today, Vitals, Workouts, Coach, More', (tester) async {
    await enterAppOnly(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = bar.destinations
        .map((d) => (d as NavigationDestination).label)
        .toList();
    expect(labels, ['Today', 'Vitals', 'Workouts', 'Coach', 'More']);
    expect(find.text('Home'), findsNothing);
    expect(find.text(OperatingMode.appOnly.label), findsOneWidget);
  });

  testWidgets('Home Analytics control opens the Analytics screen', (tester) async {
    await enterAppOnly(tester);

    final analytics = find.text('Analytics');
    await tester.scrollUntilVisible(analytics.first, 120);
    await tester.tap(analytics.first);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('7 day / 30 day / 90 day / 1 year trends'), findsNothing);
    expect(find.textContaining('Daily totals'), findsOneWidget);
  });

  testWidgets('each bottom tab actually switches screens', (tester) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Vitals');
    expect(find.text('Missing values stay missing.'), findsOneWidget);

    await tapNav(tester, 'Workouts');
    expect(find.text('My Routines'), findsOneWidget);

    await tapNav(tester, 'Coach');
    expect(find.text('Ask Vytal'), findsOneWidget);

    await tapNav(tester, 'More');
    expect(find.text('Recovery / Readiness'), findsOneWidget);

    await tester.tap(find.text('Analytics').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Daily totals'), findsOneWidget);
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
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sleep').first);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
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
    expect(find.text('Workouts'), findsOneWidget);
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
