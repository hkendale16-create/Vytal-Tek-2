import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../today/today_health_provider.dart';

class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final score = health?.readinessScore;
    final demo = health?.provenance == DataProvenance.demo;

    return SectionScaffold(
      title: 'Recovery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: FloatingHud(
                amplitude: 4,
                child: ReadinessGauge(
                  score: score,
                  size: 248,
                  label: 'READINESS',
                subtitle: score == null
                    ? null
                    : demo
                        ? 'Demo presentation'
                        : 'Baseline learning',
                provenance: score == null ? null : health?.provenance,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            score == null
                ? (health?.readinessMessage ??
                    'No readiness score yet. Pair and sync so contributing metrics can appear.')
                : 'Why $score today?',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          HudStrip(
            icon: Icons.graphic_eq,
            title: 'HRV',
            subtitle: health?.hrv.hasValue == true
                ? '${health!.hrv.value} ${health.hrv.unit ?? 'ms'} · ${health.hrv.freshness.label}'
                : (health?.hrv.freshness.label ?? 'No recent reading'),
            trailing: health?.hrv.provenance == DataProvenance.demo
                ? Text(
                    'Demo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: VytalColors.caution,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
            onTap: () => context.push('/vitals/${HealthMetricKeys.hrv}'),
          ),
          const SizedBox(height: 10),
          HudStrip(
            icon: Icons.bedtime_outlined,
            title: 'Sleep',
            subtitle: health?.sleep.hasValue == true
                ? '${health!.sleep.value!.inHours}h ${health.sleep.value!.inMinutes.remainder(60)}m'
                : (health?.sleep.freshness.label ?? 'No recent reading'),
            trailing: health?.sleep.provenance == DataProvenance.demo
                ? Text(
                    'Demo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: VytalColors.caution,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
            onTap: () => context.go('/sleep'),
          ),
          const SizedBox(height: 10),
          const HudStrip(
            icon: Icons.monitor_heart_outlined,
            title: 'Resting HR',
            subtitle: 'Not supported by this device',
          ),
          const SizedBox(height: 10),
          const HudStrip(
            icon: Icons.fitness_center_outlined,
            title: 'Training load',
            subtitle: 'No recent reading',
          ),
          const SizedBox(height: 10),
          const HudStrip(
            icon: Icons.timeline,
            title: 'Personal baseline',
            subtitle: 'Baseline learning starts after enough verified days.',
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Text(
              demo
                  ? 'Demo: this score is a labeled UI stand-in — not a clinical recovery index.'
                  : (health?.readinessMessage ??
                      'Vytal will not invent a recovery score. Contributing metrics stay blank until they sync.'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: extras.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push('/ask'),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Ask Vytal about my recovery'),
          ),
        ],
      ),
    );
  }
}
