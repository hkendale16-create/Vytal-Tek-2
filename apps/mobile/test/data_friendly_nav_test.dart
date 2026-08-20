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

  testWidgets('bottom nav is Today, Vitals, Workouts, Plans, More', (
    tester,
  ) async {
    await enterAppOnly(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = bar.destinations
        .map((d) => (d as NavigationDestination).label)
        .toList();
    expect(labels, ['Today', 'Vitals', 'Workouts', 'Plans', 'More']);
    expect(find.text('Home'), findsNothing);
    expect(find.text(OperatingMode.appOnly.label), findsOneWidget);

    // Lazy tabs: only Today is built. IndexedStack used to keep all five alive.
    expect(find.text('Missing values stay missing.'), findsNothing);
    expect(find.text('Calisthenics'), findsNothing);
    expect(find.text('Quick Start'), findsNothing);
    expect(find.textContaining('Structured workouts from your data'), findsNothing);
    expect(find.text('Recovery / Readiness'), findsNothing);
  });

  testWidgets('Home Analytics control opens the Analytics screen', (
    tester,
  ) async {
    await enterAppOnly(tester);

    await tester.tap(find.byKey(const Key('today-view-analytics')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Daily totals'), findsOneWidget);
  });

  testWidgets('each bottom tab actually switches screens', (tester) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Vitals');
    expect(find.text('Missing values stay missing.'), findsOneWidget);

    await tapNav(tester, 'Workouts');
    expect(find.text('Calisthenics'), findsOneWidget);
    expect(find.text('Quick Start'), findsOneWidget);
    expect(find.text('YOUR FIRST SESSION'), findsOneWidget);

    await tapNav(tester, 'Plans');
    expect(find.text('Training plans'), findsOneWidget);

    await tapNav(tester, 'More');
    expect(find.text('Recovery / Readiness'), findsOneWidget);

    await tapNav(tester, 'Today');
    expect(find.text('Missing values stay missing.'), findsNothing);
    expect(find.text('Calisthenics'), findsNothing);
    expect(find.text('Quick Start'), findsNothing);
    expect(find.textContaining('Structured workouts from your data'), findsNothing);
    expect(find.text('Recovery / Readiness'), findsNothing);
  });

  testWidgets('More opens existing recovery, sleep, analytics, and settings', (
    tester,
  ) async {
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

  testWidgets('App-Only Vitals asks to connect instead of blocking the app', (
    tester,
  ) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Vitals');

    expect(
      find.text('Connect a Vytal device to begin receiving this measurement.'),
      findsWidgets,
    );
    expect(find.text('HEART RATE'), findsWidgets);
    expect(find.text('Workouts'), findsOneWidget);
  });

  testWidgets(
    'Workouts hub exposes category tabs, my workouts, and training plans',
    (tester) async {
      await enterAppOnly(tester);

      await tapNav(tester, 'Workouts');

      expect(find.text('Cardio'), findsOneWidget);
      expect(find.text('Strength'), findsWidgets);
      expect(find.text('Calisthenics'), findsOneWidget);
      expect(find.text('Quick Start'), findsOneWidget);
      expect(find.text('MY WORKOUTS'), findsOneWidget);
      expect(find.text('Build a workout plan'), findsOneWidget);
      expect(find.text('Timers'), findsWidgets);
    },
  );

  testWidgets('Timers hub uses tab selector for countdown and rest', (
    tester,
  ) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Workouts');
    await tester.tap(find.byTooltip('Timers'));
    await tester.pumpAndSettle();

    expect(find.text('Countdown'), findsOneWidget);
    expect(find.text('Stopwatch'), findsOneWidget);
    expect(find.text('Interval'), findsOneWidget);
    expect(find.text('Rest'), findsOneWidget);

    await tester.tap(find.text('Rest'));
    await tester.pumpAndSettle();
    expect(find.text('Auto-start rest after each set'), findsOneWidget);
    expect(find.text('Start rest'), findsOneWidget);
  });

  testWidgets('Plans tab shows training plans with suggested questions', (
    tester,
  ) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Plans');

    expect(find.text('Training plans'), findsOneWidget);
    expect(find.text('How am I doing today?'), findsOneWidget);
    expect(find.text('Build me a workout.'), findsOneWidget);
  });
}
