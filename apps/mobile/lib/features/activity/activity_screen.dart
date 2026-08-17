import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../today/today_health_provider.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final theme = Theme.of(context);
    final isDemo = health?.provenance == DataProvenance.demo;
    final calories = health?.calories;
    final steps = health?.steps;

    return SectionScaffold(
      title: 'Activity',
      subtitle: 'Move, exercise, and stand — demo values stay labeled.',
      child: Column(
        children: [
          GlassPanel(
            glow: true,
            child: Column(
              children: [
                ActivityRings(
                  move: isDemo ? 0.78 : 0,
                  exercise: isDemo ? 0.54 : 0,
                  stand: isDemo ? 0.66 : 0,
                ),
                const SizedBox(height: 12),
                Text(
                  steps == null ? '— steps' : '$steps steps',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                if (isDemo)
                  const ProvenanceCaption(provenance: DataProvenance.demo)
                else
                  Text(
                    session.demoModeEnabled
                        ? 'Enable a demo device pair to preview activity rings.'
                        : 'Activity totals appear after wearable sync.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricHudTile(
                  title: 'Calories',
                  value: calories?.toString(),
                  unit: 'kcal',
                  icon: Icons.local_fire_department_outlined,
                  provenance: calories == null ? null : health?.provenance,
                  emptyMessage: 'No calorie total yet',
                  onTap: () => context.push('/vitals/${HealthMetricKeys.calories}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricHudTile(
                  title: 'Active',
                  value: isDemo ? '42' : null,
                  unit: 'min',
                  icon: Icons.directions_run,
                  provenance: isDemo ? DataProvenance.demo : null,
                  emptyMessage: 'No active minutes yet',
                  onTap: () => context.push('/workouts'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/workouts/start'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Workout'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/workouts'),
            icon: const Icon(Icons.fitness_center_outlined),
            label: const Text('Open workouts & timers'),
          ),
        ],
      ),
    );
  }
}
