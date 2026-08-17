import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../today/today_health_provider.dart';

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final theme = Theme.of(context);
    final sleep = health?.sleep;
    final isDemo = health?.provenance == DataProvenance.demo;
    final score = isDemo ? 87 : null;
    final durationLabel = sleep?.hasValue == true
        ? _formatDuration(sleep!.value!)
        : (isDemo ? '7h 12m' : null);

    return SectionScaffold(
      title: 'Sleep',
      subtitle: 'Calmer surface — purple/blue accents from the approved boards.',
      child: Column(
        children: [
          GlassPanel(
            accent: VytalColors.violet,
            glow: true,
            child: Column(
              children: [
                ReadinessGauge(
                  score: score,
                  label: 'SLEEP SCORE',
                  subtitle: durationLabel,
                  provenance: score == null ? null : DataProvenance.demo,
                ),
                const SizedBox(height: 8),
                Text(
                  score == null
                      ? (sleep?.freshness.label ??
                          'Sleep score appears after wearable sleep sync.')
                      : 'Demo sleep presentation for UI review.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            accent: const Color(0xFF3D6BFF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stages', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (isDemo)
                  const SleepStageLegend(
                    rem: 1.4,
                    deep: 1.8,
                    light: 3.5,
                    awake: 0.4,
                  )
                else
                  Text(
                    'Stage breakdown stays empty until the wearable reports sleep.',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}
