import 'package:flutter/material.dart';

/// One bottom-nav destination. Keep this list at five — extra screens open
/// on demand from Today or More, they are not tabs.
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

/// Single source of truth for the HUD dock.
abstract final class NavDestinations {
  static const today = NavDestination(
    path: '/today',
    label: 'Today',
    icon: Icons.today_outlined,
    selectedIcon: Icons.today_rounded,
  );

  static const vitals = NavDestination(
    path: '/vitals',
    label: 'Vitals',
    icon: Icons.favorite_outline,
    selectedIcon: Icons.favorite_rounded,
  );

  static const workouts = NavDestination(
    path: '/workouts',
    label: 'Workouts',
    icon: Icons.fitness_center_outlined,
    selectedIcon: Icons.fitness_center_rounded,
  );

  static const coach = NavDestination(
    path: '/ask',
    label: 'Plans',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
  );

  static const more = NavDestination(
    path: '/more',
    label: 'More',
    icon: Icons.menu_rounded,
    selectedIcon: Icons.menu_open_rounded,
  );

  static const List<NavDestination> all = [
    today,
    vitals,
    workouts,
    coach,
    more,
  ];

  static int indexForPath(String path) {
    final index = all.indexWhere(
      (destination) =>
          path == destination.path || path.startsWith('${destination.path}/'),
    );
    return index < 0 ? 0 : index;
  }
}
