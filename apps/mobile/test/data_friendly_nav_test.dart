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
    final appOnly = find.textContaining('Without Device');
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

  testWidgets('bottom nav is Today, Workout, Body, Coach, Profile', (
    tester,
  ) async {
    await enterAppOnly(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final labels = bar.destinations
        .map((d) => (d as NavigationDestination).label)
        .toList();
    expect(labels, ['Today', 'Workout', 'Body', 'Coach', 'Profile']);
    expect(find.text('Home'), findsNothing);
    expect(find.text(OperatingMode.appOnly.label), findsWidgets);

    // Lazy tabs: only Today is built.
    expect(find.text('Missing values stay missing.'), findsNothing);
    expect(find.text('Calisthenics'), findsNothing);
    expect(find.text('Quick Start'), findsNothing);
    expect(find.text('Recovery / Readiness'), findsNothing);
  });

  testWidgets('device-free Today prioritizes plan over empty vitals', (
    tester,
  ) async {
    await enterAppOnly(tester);

    expect(find.textContaining('TODAY'), findsWidgets);
    expect(find.textContaining('PLAN'), findsWidgets);
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('PROGRESS'), findsOneWidget);
    expect(find.text('VYTAL COACH'), findsOneWidget);
    expect(find.text('Ask Coach'), findsOneWidget);
    expect(find.text('Start Workout'), findsOneWidget);
  });

  testWidgets('Home Analytics/Progress control opens Progress', (
    tester,
  ) async {
    await enterAppOnly(tester);

    await tester.tap(find.byKey(const Key('today-view-analytics')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Progress'), findsWidgets);
  });

  testWidgets('each bottom tab actually switches screens', (tester) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Workout');
    expect(find.text('Calisthenics'), findsOneWidget);
    expect(find.text('Quick Start'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Gyms Near Me'), findsOneWidget);

    await tapNav(tester, 'Body');
    expect(find.textContaining('Body'), findsWidgets);

    await tapNav(tester, 'Coach');
    expect(find.text('Coach'), findsWidgets);
    expect(find.text('What should I train today?'), findsOneWidget);

    await tapNav(tester, 'Profile');
    expect(find.text('Recovery / Readiness'), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);

    await tapNav(tester, 'Today');
    expect(find.text('Calisthenics'), findsNothing);
    expect(find.text('Recovery / Readiness'), findsNothing);
  });

  testWidgets('Profile opens recovery and settings overlays', (tester) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Profile');

    expect(find.text('Recovery / Readiness'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Devices'), findsWidgets);
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.text('Recovery / Readiness'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('Workout hub exposes TRAIN PLAN DISCOVER REVIEW', (tester) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Workout');

    expect(find.text('Cardio'), findsOneWidget);
    expect(find.text('Strength'), findsWidgets);
    expect(find.text('Calisthenics'), findsOneWidget);
    expect(find.text('Quick Start'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('AI Workout Builder'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Gyms Near Me'), findsOneWidget);
    expect(find.text('Progress'), findsWidgets);
    expect(find.text('Timers'), findsWidgets);
  });

  testWidgets('Timers hub uses tab selector for countdown and rest', (
    tester,
  ) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Workout');
    await tester.tap(find.byTooltip('Timers').first);
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

  testWidgets('Coach tab shows grounded prompts', (tester) async {
    await enterAppOnly(tester);

    await tapNav(tester, 'Coach');

    expect(find.text('Coach'), findsWidgets);
    expect(find.text('What should I train today?'), findsOneWidget);
    expect(find.text('Build me a workout.'), findsOneWidget);
  });
}
