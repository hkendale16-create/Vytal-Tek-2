import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/activity_screen.dart';
import '../features/ai/ai_coach_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/battery/battery_screen.dart';
import '../features/body/body_screen.dart';
import '../features/devices/devices_screen.dart';
import '../features/fitness/ai_workout_builder_screen.dart';
import '../features/fitness/exercise_browser_screen.dart';
import '../features/fitness/fitness_calendar_screen.dart';
import '../features/fitness/gyms_near_me_screen.dart';
import '../features/fitness/home_gym_screen.dart';
import '../features/fitness/progress_screen.dart';
import '../features/fitness/workout_plans_screen.dart';
import '../features/more/more_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/notes/reminders_screen.dart';
import '../features/onboarding/first_launch_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/recovery/recovery_screen.dart';
import '../features/settings/monitoring_settings_screen.dart';
import '../features/settings/permissions_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/sleep/sleep_screen.dart';
import '../features/subscription/plans_screen.dart';
import '../features/subscription/subscription_screen.dart';
import '../features/timers/timers_screens.dart';
import '../features/today/today_screen.dart';
import '../features/vitals/vitals_screen.dart';
import '../domain/models/workout_models.dart';
import '../features/workouts/active_workout_screen.dart';
import '../features/workouts/muscle_group_screen.dart';
import '../features/workouts/workouts_screen.dart';
import '../state/app_session_controller.dart';
import 'app_shell.dart';
import 'destinations.dart';
import 'edge_swipe_back.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Overlay routes sit on the root navigator so they are not kept alive
/// under the tab shell.
GoRoute _overlay(
  String path,
  Widget Function(BuildContext context, GoRouterState state) builder,
) {
  return GoRoute(
    path: path,
    parentNavigatorKey: _rootKey,
    pageBuilder: (context, state) {
      return CustomTransitionPage<void>(
        key: state.pageKey,
        child: EdgeSwipeBack(child: builder(context, state)),
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offset = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return SlideTransition(position: offset, child: child);
        },
      );
    },
  );
}

NoTransitionPage<void> _tabPage(Widget child, GoRouterState state) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: NavDestinations.today.path,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(appSessionProvider);
      final loggingIn = state.matchedLocation == '/welcome';
      if (!session.hasCompletedFirstLaunch && !loggingIn) {
        return '/welcome';
      }
      if (session.hasCompletedFirstLaunch && loggingIn) {
        return NavDestinations.today.path;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const FirstLaunchScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: NavDestinations.today.path,
            pageBuilder: (context, state) =>
                _tabPage(const TodayScreen(), state),
          ),
          GoRoute(
            path: NavDestinations.workouts.path,
            pageBuilder: (context, state) =>
                _tabPage(const WorkoutsScreen(), state),
          ),
          GoRoute(
            path: NavDestinations.body.path,
            pageBuilder: (context, state) =>
                _tabPage(const BodyScreen(), state),
          ),
          GoRoute(
            path: NavDestinations.coach.path,
            pageBuilder: (context, state) =>
                _tabPage(const AiCoachScreen(), state),
          ),
          GoRoute(
            path: NavDestinations.profile.path,
            pageBuilder: (context, state) =>
                _tabPage(const ProfileScreen(), state),
          ),
        ],
      ),
      _overlay('/activity', (context, state) => const ActivityScreen()),
      _overlay('/sleep', (context, state) => const SleepScreen()),
      _overlay('/analytics', (context, state) => const AnalyticsScreen()),
      _overlay('/vitals', (context, state) => const VitalsScreen()),
      _overlay('/more', (context, state) => const MoreScreen()),
      _overlay(
        '/notes',
        (context, state) => NotesScreen(
          initialCategory: state.uri.queryParameters['category'],
          attachedRecordId: state.uri.queryParameters['record'],
        ),
      ),
      _overlay('/reminders', (context, state) => const RemindersScreen()),
      _overlay('/battery', (context, state) => const BatteryScreen()),
      _overlay(
        '/vitals/:key',
        (context, state) => VitalDetailScreen(
          metricKey: state.pathParameters['key'] ?? 'heart_rate',
        ),
      ),
      _overlay('/recovery', (context, state) => const RecoveryScreen()),
      _overlay('/timers', (context, state) => const TimersHubScreen()),
      _overlay(
        '/timers/countdown',
        (context, state) => const CountdownScreen(),
      ),
      _overlay(
        '/timers/stopwatch',
        (context, state) => const StopwatchScreen(),
      ),
      _overlay(
        '/timers/interval',
        (context, state) => const IntervalTimerScreen(),
      ),
      _overlay(
        '/workouts/muscles',
        (context, state) => MuscleGroupPickerScreen(
          groupName: state.uri.queryParameters['group'],
        ),
      ),
      _overlay(
        '/workouts/start',
        (context, state) => const ActivityPickerScreen(),
      ),
      _overlay(
        '/workouts/active',
        (context, state) => const ActiveWorkoutScreen(),
      ),
      _overlay(
        '/workouts/session',
        (context, state) => const ActiveWorkoutScreen(),
      ),
      _overlay(
        '/workouts/summary',
        (context, state) => const WorkoutSummaryScreen(),
      ),
      _overlay(
        '/workouts/history',
        (context, state) => const WorkoutHistoryScreen(),
      ),
      _overlay(
        '/workouts/builder',
        (context, state) => RoutineBuilderScreen(
          routineId: state.uri.queryParameters['id'],
          initialKind: state.uri.queryParameters['kind'] == null
              ? null
              : WorkoutActivityKind.fromJson(
                  state.uri.queryParameters['kind'],
                  orElse: WorkoutActivityKind.strength,
                ),
        ),
      ),
      _overlay(
        '/fitness/calendar',
        (context, state) => const FitnessCalendarScreen(),
      ),
      _overlay(
        '/fitness/plans',
        (context, state) => const WorkoutPlansScreen(),
      ),
      _overlay(
        '/fitness/exercises',
        (context, state) => const ExerciseBrowserScreen(),
      ),
      _overlay(
        '/fitness/gyms',
        (context, state) => const GymsNearMeScreen(),
      ),
      _overlay(
        '/fitness/home-gym',
        (context, state) => const HomeGymScreen(),
      ),
      _overlay(
        '/fitness/progress',
        (context, state) => const ProgressScreen(),
      ),
      _overlay(
        '/fitness/ai-builder',
        (context, state) => const AiWorkoutBuilderScreen(),
      ),
      _overlay('/devices', (context, state) => const DevicesScreen()),
      _overlay('/settings', (context, state) => const SettingsScreen()),
      _overlay(
        '/settings/subscription',
        (context, state) => const SubscriptionScreen(),
      ),
      _overlay(
        '/settings/subscription/plans',
        (context, state) => const PlansScreen(),
      ),
      _overlay(
        '/settings/permissions',
        (context, state) => const PermissionsScreen(),
      ),
      _overlay(
        '/settings/monitoring',
        (context, state) => const MonitoringSettingsScreen(),
      ),
    ],
  );
});

/// Rebuild redirect only when first-launch completes — not on monitoring ticks.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen<bool>(
      appSessionProvider.select((session) => session.hasCompletedFirstLaunch),
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
}
