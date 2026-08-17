import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'vytal_hud_dock.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    VytalHudDestination(
      icon: Icons.today_outlined,
      selectedIcon: Icons.today_rounded,
      label: 'Today',
    ),
    VytalHudDestination(
      icon: Icons.favorite_outline,
      selectedIcon: Icons.favorite_rounded,
      label: 'Vitals',
    ),
    VytalHudDestination(
      icon: Icons.fitness_center_outlined,
      selectedIcon: Icons.fitness_center_rounded,
      label: 'Workouts',
    ),
    VytalHudDestination(
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      label: 'Coach',
    ),
    VytalHudDestination(
      icon: Icons.menu_rounded,
      selectedIcon: Icons.menu_open_rounded,
      label: 'More',
    ),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: VytalHudDock(
          key: const Key('vytal-hud-dock'),
          index: navigationShell.currentIndex,
          onSelect: _onTap,
          destinations: destinations,
        ),
      ),
    );
  }
}
