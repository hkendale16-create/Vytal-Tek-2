import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.bedtime_outlined),
            selectedIcon: Icon(Icons.bedtime_rounded),
            label: 'Sleep',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: navigationShell.currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/devices'),
              backgroundColor: VytalColors.teal,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.watch_outlined),
              label: const Text('Devices'),
            )
          : null,
    );
  }
}
