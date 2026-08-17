import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/theme/vytal_theme.dart';
import 'monitoring/monitoring_controller.dart';
import 'subscription/subscription_controller.dart';

class VytalApp extends ConsumerStatefulWidget {
  const VytalApp({super.key});

  @override
  ConsumerState<VytalApp> createState() => _VytalAppState();
}

class _VytalAppState extends ConsumerState<VytalApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Phase F: re-verify cached subscription hints after cold start.
      ref.read(subscriptionControllerProvider).refreshAfterLaunch();
    });
  }

  @override
  Widget build(BuildContext context) {
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
