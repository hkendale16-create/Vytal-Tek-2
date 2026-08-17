import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/workout_models.dart';
import '../../workouts/workout_controllers.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

class WorkoutSessionScreen extends ConsumerWidget {
  const WorkoutSessionScreen({super.key});

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider);
    final theme = Theme.of(context);
    final phase = session.currentPhase;
    final displaySeconds = phase?.kind == WorkoutTimerKind.stopwatch
        ? session.stopwatchElapsed
        : session.remainingSeconds;

    if (session.phases.isEmpty) {
      return SectionScaffold(
        title: 'Session',
        child: EmptyMetricCard(
          title: 'No active session',
          message: 'Start a routine or stopwatch from Workouts.',
        ),
      );
    }

    return SectionScaffold(
      title: session.routine?.name ?? 'Timer',
      subtitle: session.completed ? 'Session complete' : 'Timer engine',
      child: Column(
        children: [
          GlassPanel(
            glow: true,
            child: Column(
              children: [
                Text(
                  phase?.label ?? 'Done',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  phase == null ? '00:00' : _format(displaySeconds),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: phase?.kind == WorkoutTimerKind.rest
                        ? VytalColors.caution
                        : VytalColors.teal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.phaseIndex + 1}/${session.phases.length}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: session.completed
                      ? null
                      : () {
                          final notifier =
                              ref.read(workoutSessionProvider.notifier);
                          if (session.running) {
                            notifier.pause();
                          } else {
                            notifier.resume();
                          }
                        },
                  child: Text(session.running ? 'Pause' : 'Resume'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(workoutSessionProvider.notifier).stop();
                    context.pop();
                  },
                  child: const Text('End'),
                ),
              ),
            ],
          ),
          if (session.completed) ...[
            const SizedBox(height: 12),
            const StatusPill(label: 'Completed', emphasis: true),
          ],
        ],
      ),
    );
  }
}
