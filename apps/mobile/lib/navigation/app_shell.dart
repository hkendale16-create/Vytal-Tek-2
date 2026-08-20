import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/vytal_theme.dart';
import 'destinations.dart';
import 'edge_swipe_back.dart';

/// Bottom dock. Only the active tab's [child] is mounted — other tabs are
/// not built, so Vitals/Workouts/Coach/More do not load until tapped.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selected = NavDestinations.indexForPath(path);
    final surface = context.vytalExtras.canvas;

    return RootPopGuard(
      child: Scaffold(
        extendBody: false,
        body: child,
        bottomNavigationBar: Material(
          elevation: 0,
          color: surface,
          child: NavigationBar(
            key: const Key('vytal-hud-dock'),
            backgroundColor: surface,
            selectedIndex: selected,
            onDestinationSelected: (index) {
              context.go(NavDestinations.all[index].path);
            },
            destinations: [
              for (final destination in NavDestinations.all)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
