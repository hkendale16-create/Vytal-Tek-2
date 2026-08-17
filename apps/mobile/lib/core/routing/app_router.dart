import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_session_controller.dart';
import '../../features/activity/activity_screen.dart';
import '../../features/ai/ai_coach_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/battery/battery_screen.dart';
import '../../features/body/body_screen.dart';
import '../../features/devices/devices_screen.dart';
import '../../features/onboarding/first_launch_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/recovery/recovery_screen.dart';
import '../../features/settings/monitoring_settings_screen.dart';
import '../../features/settings/permissions_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/sleep/sleep_screen.dart';
import '../../features/subscription/plans_screen.dart';
import '../../features/subscription/subscription_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/notes/reminders_screen.dart';
import '../../features/timers/timers_screens.dart';
import '../../features/today/today_screen.dart';
import '../../features/vitals/vitals_screen.dart';
import '../../features/workouts/workouts_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(appSessionProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/today',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/welcome';
      if (!session.hasCompletedFirstLaunch && !loggingIn) {
        return '/welcome';
      }
      if (session.hasCompletedFirstLaunch && loggingIn) {
        return '/today';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const FirstLaunchScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sleep',
                builder: (context, state) => const SleepScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/body',
        builder: (context, state) => const BodyScreen(),
      ),
      GoRoute(
        path: '/ask',
        builder: (context, state) => const AiCoachScreen(),
      ),
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesScreen(),
      ),
      GoRoute(
        path: '/reminders',
        builder: (context, state) => const RemindersScreen(),
      ),
      GoRoute(
        path: '/battery',
        builder: (context, state) => const BatteryScreen(),
      ),
      GoRoute(
        path: '/vitals',
        builder: (context, state) => const VitalsScreen(),
      ),
      GoRoute(
        path: '/vitals/:key',
        builder: (context, state) => VitalDetailScreen(
          metricKey: state.pathParameters['key'] ?? 'heart_rate',
        ),
      ),
      GoRoute(
        path: '/recovery',
        builder: (context, state) => const RecoveryScreen(),
      ),
      GoRoute(
        path: '/timers',
        builder: (context, state) => const TimersHubScreen(),
      ),
      GoRoute(
        path: '/timers/countdown',
        builder: (context, state) => const CountdownScreen(),
      ),
      GoRoute(
        path: '/timers/stopwatch',
        builder: (context, state) => const StopwatchScreen(),
      ),
      GoRoute(
        path: '/timers/interval',
        builder: (context, state) => const IntervalTimerScreen(),
      ),
      GoRoute(
        path: '/workouts',
        builder: (context, state) => const WorkoutsScreen(),
      ),
      GoRoute(
        path: '/workouts/start',
        builder: (context, state) => const ActivityPickerScreen(),
      ),
      GoRoute(
        path: '/workouts/active',
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      GoRoute(
        path: '/workouts/session',
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      GoRoute(
        path: '/workouts/summary',
        builder: (context, state) => const WorkoutSummaryScreen(),
      ),
      GoRoute(
        path: '/workouts/history',
        builder: (context, state) => const WorkoutHistoryScreen(),
      ),
      GoRoute(
        path: '/workouts/builder',
        builder: (context, state) => RoutineBuilderScreen(
          routineId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/settings/subscription/plans',
        builder: (context, state) => const PlansScreen(),
      ),
      GoRoute(
        path: '/settings/permissions',
        builder: (context, state) => const PermissionsScreen(),
      ),
      GoRoute(
        path: '/settings/monitoring',
        builder: (context, state) => const MonitoringSettingsScreen(),
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(appSessionProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}
