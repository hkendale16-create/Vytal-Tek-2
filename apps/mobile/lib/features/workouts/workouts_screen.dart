import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/workout_models.dart';
import '../../state/app_session_controller.dart';
import '../../workouts/workout_controllers.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../subscription/soft_paywall.dart';

class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(workoutLibraryProvider);
    final session = ref.watch(workoutSessionProvider);
    final canCustom =
        ref.watch(appSessionProvider).entitlements.canUse(EntitlementKeys.workoutsCustom);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Workouts',
      subtitle: 'Built-in routines, custom builder, and timers — works App-Only.',
      actions: [
        IconButton(
          tooltip: 'Stopwatch',
          onPressed: () {
            ref.read(workoutSessionProvider.notifier).startStopwatch();
            context.push('/workouts/session');
          },
          icon: const Icon(Icons.timer_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session.running || session.completed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.tonal(
                onPressed: () => context.push('/workouts/session'),
                child: Text(
                  session.completed
                      ? 'View completed session'
                      : 'Resume active session',
                ),
              ),
            ),
          Text('Vytal routines', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final routine in library.builtIn) ...[
            _RoutineCard(
              routine: routine,
              onStart: () {
                ref.read(workoutSessionProvider.notifier).startRoutine(routine);
                context.push('/workouts/session');
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Text('Your routines', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!canCustom)
            const SoftPaywall(
              entitlementKey: EntitlementKeys.workoutsCustom,
              compact: true,
            )
          else ...[
            FilledButton(
              onPressed: () => _createQuickRoutine(context, ref),
              child: const Text('Create quick custom routine'),
            ),
            const SizedBox(height: 10),
            if (library.custom.isEmpty)
              const EmptyMetricCard(
                title: 'No custom routines yet',
                message: 'Build a simple routine to reuse with the timer engine.',
              )
            else
              for (final routine in library.custom) ...[
                _RoutineCard(
                  routine: routine,
                  onStart: () {
                    ref
                        .read(workoutSessionProvider.notifier)
                        .startRoutine(routine);
                    context.push('/workouts/session');
                  },
                  onDelete: () => ref
                      .read(workoutLibraryProvider.notifier)
                      .deleteCustom(routine.id),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ],
      ),
    );
  }

  Future<void> _createQuickRoutine(BuildContext context, WidgetRef ref) async {
    const uuid = Uuid();
    await ref.read(workoutLibraryProvider.notifier).addCustom(
          name: 'My custom set',
          exercises: [
            WorkoutExercise(
              id: uuid.v4(),
              name: 'Exercise 1',
              sets: 3,
              reps: 10,
              restSeconds: 45,
            ),
            WorkoutExercise(
              id: uuid.v4(),
              name: 'Exercise 2',
              sets: 3,
              durationSeconds: 40,
              restSeconds: 30,
            ),
          ],
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Custom routine saved.')),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.onStart,
    this.onDelete,
  });

  final WorkoutRoutine routine;
  final VoidCallback onStart;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(routine.name, style: theme.textTheme.titleMedium),
              ),
              if (routine.builtIn)
                const StatusPill(label: 'Built-in', emphasis: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${routine.exercises.length} exercises',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: onStart,
                child: const Text('Start'),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: VytalColors.alert,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
