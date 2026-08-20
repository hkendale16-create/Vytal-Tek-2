import 'package:flutter/material.dart';

/// One bottom-nav destination. Keep this list at five — extra screens open
/// on demand from Today, Workout, or Profile.
class NavDestination {
  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Primary IA: Today | Workout | Body | Coach | Profile
abstract final class NavDestinations {
  static const today = NavDestination(
    path: '/today',
    label: 'Today',
    icon: Icons.today_outlined,
    selectedIcon: Icons.today_rounded,
  );

  static const workouts = NavDestination(
    path: '/workouts',
    label: 'Workout',
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center_rounded,
  );

  static const body = NavDestination(
    path: '/body',
    label: 'Body',
    icon: Icons.accessibility_new_outlined,
    selectedIcon: Icons.accessibility_new_rounded,
  );

  static const coach = NavDestination(
    path: '/ask',
    label: 'Coach',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
  );

  static const profile = NavDestination(
    path: '/profile',
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  );

  /// Kept for deep links / redirects from older builds.
  static const vitals = NavDestination(
    path: '/vitals',
    label: 'Vitals',
    icon: Icons.favorite_outline,
    selectedIcon: Icons.favorite_rounded,
  );

  static const more = NavDestination(
    path: '/more',
    label: 'More',
    icon: Icons.menu_rounded,
    selectedIcon: Icons.menu_open_rounded,
  );

  static const List<NavDestination> all = [
    today,
    workouts,
    body,
    coach,
    profile,
  ];

  static int indexForPath(String path) {
    final index = all.indexWhere(
      (destination) =>
          path == destination.path || path.startsWith('${destination.path}/'),
    );
    return index < 0 ? 0 : index;
  }
}
