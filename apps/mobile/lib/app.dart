import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/theme/vytal_theme.dart';
import 'monitoring/monitoring_controller.dart';

class VytalApp extends ConsumerWidget {
  const VytalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the monitoring engine alive for lifecycle + auto-switching.
    ref.watch(monitoringControllerProvider);

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Vytal Tek',
      debugShowCheckedModeBanner: false,
      theme: VytalTheme.light(),
      darkTheme: VytalTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
