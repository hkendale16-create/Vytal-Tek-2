import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_theme.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/operating_mode.dart';
import '../../monitoring/monitoring_controller.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../subscription/soft_paywall.dart';
import '../today/today_health_provider.dart';
import 'live_body_stage.dart';

class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final monitoring = ref.watch(monitoringControllerProvider);
    final extras = context.vytalExtras;
    final connected = session.operatingMode == OperatingMode.connected;
    final demo = health?.provenance == DataProvenance.demo;
    final motionLevel = monitoring.policy.ambientMotionLevel;

    return SectionScaffold(
      title: 'Live Body',
      actions: [
        IconButton(
          tooltip: 'Home',
          onPressed: () => context.go('/today'),
          icon: const Icon(Icons.home_outlined),
        ),
      ],
      child: Column(
        children: [
          SizedBox(
            height: 440,
            child: LiveBodyStage(
              highlightHeart: connected || demo,
              ambientMotionLevel: motionLevel,
              showRing: connected || demo || session.pairedDevice != null,
              onRegionSelected: (region) {
                switch (region) {
                  case BodyRegion.chest:
                    context.push('/vitals/heart_rate');
                  case BodyRegion.legs:
                    context.push('/workouts');
                  case BodyRegion.head:
                    context.push('/recovery');
                }
              },
              childOverlay: Stack(
                children: [
                  Align(
                    alignment: const Alignment(-1.02, -0.38),
                    child: FloatingHud(
                      child: SizedBox(
                        width: 118,
                        child: MetricHudTile(
                          compact: true,
                          title: 'HR',
                          value: health?.heartRate.hasValue == true
                              ? '${health!.heartRate.value}'
                              : (demo ? '72' : null),
                          unit: 'BPM',
                          provenance: demo
                              ? DataProvenance.demo
                              : health?.heartRate.provenance,
                          emptyMessage: '—',
                          onTap: () => context.push('/vitals/heart_rate'),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(1.02, -0.22),
                    child: FloatingHud(
                      delay: const Duration(milliseconds: 280),
                      child: SizedBox(
                        width: 118,
                        child: MetricHudTile(
                          compact: true,
                          title: 'SpO₂',
                          value: health?.spo2.hasValue == true
                              ? '${health!.spo2.value}'
                              : (demo ? '98' : null),
                          unit: '%',
                          provenance: demo
                              ? DataProvenance.demo
                              : health?.spo2.provenance,
                          emptyMessage: '—',
                          onTap: () => context.push('/vitals/spo2'),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(-1.0, 0.52),
                    child: FloatingHud(
                      delay: const Duration(milliseconds: 520),
                      child: SizedBox(
                        width: 118,
                        child: MetricHudTile(
                          compact: true,
                          title: 'Temp',
                          value: health?.temperature.hasValue == true
                              ? health!.temperature.value!.toStringAsFixed(1)
                              : null,
                          unit: '°C',
                          provenance: health?.temperature.provenance,
                          emptyMessage: '—',
                          onTap: () => context.push('/vitals/temperature'),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(1.0, 0.62),
                    child: FloatingHud(
                      delay: const Duration(milliseconds: 760),
                      child: SizedBox(
                        width: 118,
                        child: MetricHudTile(
                          compact: true,
                          title: 'Sleep',
                          value: health?.sleep.hasValue == true
                              ? '${health!.sleep.value!.inHours}h'
                              : null,
                          unit: '',
                          provenance: health?.sleep.provenance,
                          emptyMessage: '—',
                          onTap: () => context.go('/sleep'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connected || demo
                ? 'Tap a region or a tile. Missing sensors stay blank.'
                : 'App-Only: the stage stays available with no fabricated vitals.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: extras.textMuted,
                ),
          ),
          const SizedBox(height: 12),
          EntitlementGate(
            entitlementKey: EntitlementKeys.digitalBodyAdvanced,
            compactPaywall: true,
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Digital-body insights',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    demo
                        ? 'Demo: recovery regions look balanced from labeled demo HRV and sleep — not a diagnosis.'
                        : connected
                            ? 'Region coaching uses verified wearable summaries only. Missing sensors stay blank.'
                            : 'Pair a wearable to light region insights. Nothing is invented in App-Only Mode.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
