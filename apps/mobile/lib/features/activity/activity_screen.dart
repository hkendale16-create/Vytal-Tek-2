import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_theme.dart';
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
    final extras = context.vytalExtras;
    final isDemo = health?.provenance == DataProvenance.demo;
    final calories = health?.calories;
    final steps = health?.steps;

    return SectionScaffold(
      title: 'Activity',
      child: Column(
        children: [
          SizedBox(
            height: 340,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ActivityRings(
                        size: 220,
                        move: isDemo ? 0.78 : 0,
                        exercise: isDemo ? 0.54 : 0,
                        stand: isDemo ? 0.66 : 0,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        steps == null ? '— steps' : '$steps steps',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: extras.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: const Alignment(-1.0, -0.85),
                  child: FloatingHud(
                    child: HudMetricChip(
                      label: 'Calories',
                      value: calories?.toString(),
                      unit: 'kcal',
                      icon: Icons.local_fire_department_outlined,
                      provenance: calories == null ? null : health?.provenance,
                      onTap: () =>
                          context.push('/vitals/${HealthMetricKeys.calories}'),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(1.0, -0.55),
                  child: FloatingHud(
                    delay: const Duration(milliseconds: 380),
                    child: HudMetricChip(
                      label: 'Active',
                      value: isDemo ? '42' : null,
                      unit: 'min',
                      icon: Icons.directions_run,
                      provenance: isDemo ? DataProvenance.demo : null,
                      onTap: () => context.push('/workouts'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.push('/workouts/start'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Workout'),
          ),
          const SizedBox(height: 10),
          HudStrip(
            icon: Icons.fitness_center_outlined,
            title: 'Workouts & timers',
            subtitle: 'Routines, history, countdown, stopwatch',
            onTap: () => context.push('/workouts'),
          ),
        ],
      ),
    );
  }
}
