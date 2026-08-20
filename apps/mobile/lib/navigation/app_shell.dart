import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/vytal_theme.dart';
import '../features/devices/wearable_connection_indicator.dart';
import 'destinations.dart';
import 'edge_swipe_back.dart';

/// Bottom dock. Only the active tab's [child] is mounted — other tabs are
/// not built until tapped (Today / Workout / Body / Coach / Profile).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final selected = NavDestinations.indexForPath(path);
    final surface = context.vytalExtras.canvas;

    return RootPopGuard(
      child: Scaffold(
        extendBody: false,
        body: Stack(
          children: [
            child,
            const Align(
              alignment: Alignment.topRight,
              child: SafeArea(
                child: WearableConnectionIndicator(),
              ),
            ),
          ],
        ),
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
