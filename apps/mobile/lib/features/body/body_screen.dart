import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/data_provenance.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/operating_mode.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../subscription/soft_paywall.dart';
import '../today/today_health_provider.dart';

class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final theme = Theme.of(context);
    final connected = session.operatingMode == OperatingMode.connected;
    final demo = health?.provenance == DataProvenance.demo;

    return SectionScaffold(
      title: 'Live Body',
      subtitle: 'Floating HUD around the body — Phase 5 adds full 3D.',
      actions: [
        IconButton(
          tooltip: 'Home',
          onPressed: () => context.go('/today'),
          icon: const Icon(Icons.home_outlined),
        ),
      ],
      child: Column(
        children: [
          GlassPanel(
            glow: true,
            child: Column(
              children: [
                SizedBox(
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      BodySilhouette(highlightHeart: connected || demo),
                      Align(
                        alignment: const Alignment(-1.05, -0.35),
                        child: SizedBox(
                          width: 132,
                          child: MetricHudTile(
                            title: 'HR',
                            value: health?.heartRate.hasValue == true
                                ? '${health!.heartRate.value}'
                                : (demo ? '72' : null),
                            unit: 'BPM',
                            provenance: demo
                                ? DataProvenance.demo
                                : health?.heartRate.provenance,
                            emptyMessage: '—',
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(1.05, -0.2),
                        child: SizedBox(
                          width: 132,
                          child: MetricHudTile(
                            title: 'SpO₂',
                            value: health?.spo2.hasValue == true
                                ? '${health!.spo2.value}'
                                : (demo ? '98' : null),
                            unit: '%',
                            provenance: demo
                                ? DataProvenance.demo
                                : health?.spo2.provenance,
                            emptyMessage: '—',
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(-1.0, 0.55),
                        child: SizedBox(
                          width: 132,
                          child: MetricHudTile(
                            title: 'Temp',
                            value: health?.temperature.hasValue == true
                                ? health!.temperature.value!.toStringAsFixed(1)
                                : null,
                            unit: '°C',
                            provenance: health?.temperature.provenance,
                            emptyMessage: '—',
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(1.0, 0.65),
                        child: SizedBox(
                          width: 132,
                          child: MetricHudTile(
                            title: 'Sleep',
                            value: health?.sleep.hasValue == true
                                ? '${health!.sleep.value!.inHours}h'
                                : null,
                            unit: '',
                            provenance: health?.sleep.provenance,
                            emptyMessage: '—',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  connected || demo
                      ? 'Regions illuminate only for supported or clearly labeled demo metrics.'
                      : 'App-Only Mode: body shell stays available with no fabricated vitals.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const EntitlementGate(
            entitlementKey: EntitlementKeys.digitalBodyAdvanced,
            compactPaywall: true,
            child: EmptyMetricCard(
              title: 'Digital-body insights',
              message:
                  'Region-level coaching and holographic depth unlock with Pro. '
                  'Full 3D experience is a separate Phase 5 workstream.',
            ),
          ),
        ],
      ),
    );
  }
}
