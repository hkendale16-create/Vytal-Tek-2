import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/motion/hud_motion_provider.dart';
import 'core/motion/vytal_motion.dart';
import 'navigation/app_router.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/theme/vytal_theme.dart';
import 'battery/battery_intelligence.dart';
import 'battery/battery_providers.dart';
import 'health/daily_summary_store.dart';
import 'monitoring/monitoring_controller.dart';
import 'subscription/subscription_controller.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
    ref.watch(dailySummaryCaptureProvider);
    ref.listen<BatteryInsight>(batteryIntelligenceProvider, (previous, next) {
      final dedup = ref.read(batteryAlertDedupProvider);
      if (!dedup.shouldNotify(next.alertLevel, next.wearablePercent)) return;
      final messenger = rootScaffoldMessengerKey.currentState;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            next.alertLevel == BatteryAlertLevel.critical
                ? 'Wearable battery critical (${next.wearablePercent}%). Charge soon.'
                : 'Wearable battery at 20% or below (${next.wearablePercent}%). Charge soon.',
          ),
        ),
      );
    });

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    final motionEnabled = ref.watch(hudMotionEnabledProvider);

    return HudMotionScope(
      enabled: motionEnabled,
      child: MaterialApp.router(
        title: 'Vytal Tek',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: VytalTheme.light(),
        darkTheme: VytalTheme.dark(),
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}
