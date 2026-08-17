import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
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
    final score = health?.readinessScore;
    final demo = health?.provenance == DataProvenance.demo;

    return SectionScaffold(
      title: 'Recovery',
      subtitle: 'Readiness is derived from verified summaries only.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ReadinessGauge(
              score: score,
              label: 'READINESS',
              subtitle: score == null
                  ? null
                  : demo
                      ? 'Demo presentation'
                      : 'Baseline learning',
              provenance: score == null ? null : health?.provenance,
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
          _Factor(
            title: 'HRV',
            detail: health?.hrv.hasValue == true
                ? '${health!.hrv.value} ${health.hrv.unit ?? 'ms'} · ${health.hrv.freshness.label}'
                : (health?.hrv.freshness.label ?? 'No recent reading'),
            demo: health?.hrv.provenance == DataProvenance.demo,
          ),
          const SizedBox(height: 10),
          _Factor(
            title: 'Sleep',
            detail: health?.sleep.hasValue == true
                ? '${health!.sleep.value!.inHours}h ${health.sleep.value!.inMinutes.remainder(60)}m'
                : (health?.sleep.freshness.label ?? 'No recent reading'),
            demo: health?.sleep.provenance == DataProvenance.demo,
          ),
          const SizedBox(height: 10),
          const _Factor(
            title: 'Resting HR',
            detail: 'Not supported by this device',
          ),
          const SizedBox(height: 10),
          const _Factor(
            title: 'Training load',
            detail: 'No recent reading',
          ),
          const SizedBox(height: 10),
          const _Factor(
            title: 'Personal baseline',
            detail: 'Baseline learning starts after enough verified days.',
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Text(
              demo
                  ? 'Demo: this score is a labeled UI stand-in — not a clinical recovery index.'
                  : (health?.readinessMessage ??
                      'Vytal will not invent a recovery score. Contributing metrics stay blank until they sync.'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/ask'),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Ask Vytal about my recovery'),
          ),
        ],
      ),
    );
  }
}

class _Factor extends StatelessWidget {
  const _Factor({
    required this.title,
    required this.detail,
    this.demo = false,
  });

  final String title;
  final String detail;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (demo)
            Text(
              'Demo',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: VytalColors.caution,
                    fontWeight: FontWeight.w700,
                  ),
            ),
        ],
      ),
    );
  }
}
