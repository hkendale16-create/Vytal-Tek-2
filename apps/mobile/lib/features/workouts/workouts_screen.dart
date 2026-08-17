import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/time/duration_format.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/workout_models.dart';
import '../../state/app_session_controller.dart';
import '../../workouts/workout_controllers.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../subscription/soft_paywall.dart';
import '../today/today_health_provider.dart';
import 'activity_motion.dart';

class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(workoutLibraryProvider);
    final session = ref.watch(workoutSessionProvider);
    final history = ref.watch(workoutHistoryProvider);
    final canCustom =
        ref.watch(appSessionProvider).entitlements.canUse(EntitlementKeys.workoutsCustom);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Workouts',
      subtitle: 'Start, build, and replay sessions — works App-Only.',
      actions: [
        IconButton(
          tooltip: 'Timers',
          onPressed: () => context.push('/timers'),
          icon: const Icon(Icons.timer_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session.running || session.summaryPending || session.completed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.tonal(
                onPressed: () => context.push(
                  session.summaryPending ? '/workouts/summary' : '/workouts/active',
                ),
                child: Text(
                  session.summaryPending
                      ? 'View workout summary'
                      : 'Resume active workout',
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: () => context.push('/workouts/start'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Workout'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/workouts/history'),
                  child: const Text('History'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: canCustom
                      ? () => context.push('/workouts/builder')
                      : null,
                  child: const Text('Create Routine'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Recently used', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (library.recentlyUsed.isEmpty)
            const EmptyMetricCard(
              title: 'No recent workouts',
              message: 'Start a workout or save a routine to see it here.',
            )
          else
            for (final routine in library.recentlyUsed) ...[
              _RoutineCard(
                routine: routine,
                onStart: () {
                  ref.read(workoutSessionProvider.notifier).startRoutine(routine);
                  context.push('/workouts/active');
                },
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
          Text('Vytal routines', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final routine in library.builtIn) ...[
            _RoutineCard(
              routine: routine,
              onStart: () {
                ref.read(workoutSessionProvider.notifier).startRoutine(routine);
                context.push('/workouts/active');
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Text('My Routines', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!canCustom)
            const SoftPaywall(
              entitlementKey: EntitlementKeys.workoutsCustom,
              compact: true,
            )
          else if (library.custom.isEmpty)
            const EmptyMetricCard(
              title: 'No routines yet',
              message:
                  'Create your first routine or ask Vytal to build one.',
            )
          else
            for (final routine in library.custom) ...[
              _RoutineCard(
                routine: routine,
                onStart: () {
                  ref.read(workoutSessionProvider.notifier).startRoutine(routine);
                  context.push('/workouts/active');
                },
                onDelete: () => ref
                    .read(workoutLibraryProvider.notifier)
                    .deleteCustom(routine.id),
                onEdit: () => context.push('/workouts/builder?id=${routine.id}'),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
          Text('AI Workouts', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask Coach Vital for a structured plan you can start or save.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/ask'),
                  child: const Text('Ask Vytal to build a workout'),
                ),
              ],
            ),
          ),
          if (history.entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '${history.entries.length} saved session${history.entries.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.onStart,
    this.onDelete,
    this.onEdit,
  });

  final WorkoutRoutine routine;
  final VoidCallback onStart;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

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
                const StatusPill(label: 'Built-in', emphasis: true)
              else if (routine.source == 'ai')
                const StatusPill(label: 'AI', emphasis: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${routine.exercises.length} exercises · ${routine.activityKind.label}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: onStart,
                child: const Text('Start'),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              ],
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

class ActivityPickerScreen extends ConsumerWidget {
  const ActivityPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionScaffold(
      title: 'Start Workout',
      subtitle: 'Choose an activity. The session keeps running if you leave.',
      child: Column(
        children: [
          for (final kind in WorkoutActivityKind.values) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    ref.read(workoutSessionProvider.notifier).startActivity(kind);
                    context.push('/workouts/active');
                  },
                  child: GlassPanel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            kind.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(workoutSessionProvider);
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final theme = Theme.of(context);
    final phase = session.currentPhase;
    final kind = session.activityKind ?? WorkoutActivityKind.custom;
    final hr = health?.heartRate.hasValue == true ? health!.heartRate.value : null;

    if (session.phases.isEmpty && !session.summaryPending) {
      return const SectionScaffold(
        title: 'Workout',
        child: EmptyMetricCard(
          title: 'No active workout',
          message: 'Start a workout from Home or Workouts.',
        ),
      );
    }

    if (session.summaryPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/workouts/summary');
      });
    }

    final display = session.playMode == WorkoutPlayMode.routine
        ? session.remainingNow()
        : session.elapsedSeconds();

    return SectionScaffold(
      title: session.routine?.name ?? kind.label,
      subtitle: session.running ? 'In progress' : 'Paused',
      child: Column(
        children: [
          ActivityMotion(kind: kind, running: session.running),
          const SizedBox(height: 8),
          GlassPanel(
            glow: session.running,
            child: Column(
              children: [
                Text(
                  phase?.label ?? kind.label,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                Text(
                  formatClock(display),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: phase?.kind == WorkoutTimerKind.rest
                        ? VytalColors.caution
                        : VytalColors.teal,
                  ),
                ),
                Text(
                  session.playMode == WorkoutPlayMode.routine
                      ? 'Elapsed ${formatClock(session.elapsedSeconds())}'
                      : 'Elapsed time',
                  style: theme.textTheme.bodySmall,
                ),
                if (session.playMode == WorkoutPlayMode.routine && phase != null)
                  Text(
                    [
                      if (phase.exerciseName != null) phase.exerciseName!,
                      if (phase.setNumber != null)
                        'Set ${phase.setNumber}/${phase.setsTotal ?? phase.setNumber}',
                      if (phase.reps != null) '${phase.reps} reps',
                      if (phase.weightKg != null) '${phase.weightKg} kg',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricHudTile(
                  title: 'Heart Rate',
                  value: hr?.toString(),
                  unit: 'BPM',
                  emptyMessage: 'No connected reading',
                  provenance: health?.heartRate.provenance,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricHudTile(
                  title: 'Calories',
                  value: health?.calories?.toString(),
                  unit: 'kcal',
                  emptyMessage: 'No reading',
                  provenance: health?.calories == null ? null : health?.provenance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (session.playMode == WorkoutPlayMode.routine) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () =>
                      ref.read(workoutSessionProvider.notifier).completeSet(),
                  child: const Text('Complete Set'),
                ),
                OutlinedButton(
                  onPressed: () => ref.read(workoutSessionProvider.notifier).skip(),
                  child: const Text('Skip'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(workoutSessionProvider.notifier).previousStep(),
                  child: const Text('Previous'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (session.previousPhase != null)
              Text('Previous: ${session.previousPhase!.label}',
                  style: theme.textTheme.bodySmall),
            if (session.nextPhase != null)
              Text('Next: ${session.nextPhase!.label}',
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final n = ref.read(workoutSessionProvider.notifier);
                    if (session.running) {
                      n.pause();
                    } else {
                      n.resume();
                    }
                  },
                  child: Text(session.running ? 'Pause' : 'Resume'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(workoutSessionProvider.notifier).finish();
                    context.push('/workouts/summary');
                  },
                  child: const Text('Finish'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const WorkoutSummaryScreen({super.key});

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    final theme = Theme.of(context);
    if (session.phases.isEmpty && !session.summaryPending && !session.completed) {
      return const SectionScaffold(
        title: 'Summary',
        child: EmptyMetricCard(
          title: 'No workout to save',
          message: 'Finish a session to see time, heart rate, and notes.',
        ),
      );
    }

    return SectionScaffold(
      title: 'Workout summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Column(
              children: [
                Text(session.routine?.name ?? 'Workout',
                    style: theme.textTheme.titleLarge),
                Text(
                  formatClock(session.elapsedSeconds()),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: VytalColors.teal,
                  ),
                ),
                Text(
                  'Avg HR ${session.averageHr ?? '—'} · Max HR ${session.maxHr ?? '—'}',
                  style: theme.textTheme.bodySmall,
                ),
                const Text('Calories and distance appear only from verified readings.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'How did it feel?',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ref.read(workoutSessionProvider.notifier).setNotes(v),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              await ref.read(workoutSessionProvider.notifier).saveToHistory();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Workout saved.')),
              );
              context.go('/workouts');
            },
            child: const Text('Save'),
          ),
          OutlinedButton(
            onPressed: () => context.push('/notes'),
            child: const Text('Add Note'),
          ),
          TextButton(
            onPressed: () {
              ref.read(workoutSessionProvider.notifier).discard();
              context.go('/workouts');
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider).entries;
    return SectionScaffold(
      title: 'Workout history',
      child: history.isEmpty
          ? const EmptyMetricCard(
              title: 'No workouts yet',
              message: 'Start your first workout.',
            )
          : Column(
              children: [
                for (final entry in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.name,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '${entry.activityKind.label} · ${formatClock(entry.durationSeconds)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (entry.notes != null) Text(entry.notes!),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class RoutineBuilderScreen extends ConsumerStatefulWidget {
  const RoutineBuilderScreen({super.key, this.routineId});

  final String? routineId;

  @override
  ConsumerState<RoutineBuilderScreen> createState() =>
      _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends ConsumerState<RoutineBuilderScreen> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _exercises = <WorkoutExercise>[];
  var _kind = WorkoutActivityKind.strength;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.routineId;
      if (id == null) return;
      final match = ref
          .read(workoutLibraryProvider)
          .routines
          .cast<WorkoutRoutine?>()
          .firstWhere(
            (r) => r?.id == id && r?.builtIn == false,
            orElse: () => null,
          );
      if (match == null) return;
      setState(() {
        _name.text = match.name;
        _kind = match.activityKind;
        _exercises.addAll(match.exercises);
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _addExercise(String name) {
    setState(() {
      _exercises.add(
        WorkoutExercise(
          id: const Uuid().v4(),
          name: name,
          sets: 3,
          reps: 10,
          restSeconds: 45,
        ),
      );
    });
  }

  Future<void> _save() async {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise.')),
      );
      return;
    }
    final existingId = widget.routineId;
    final routine = WorkoutRoutine(
      id: existingId ?? const Uuid().v4(),
      name: _name.text.trim().isEmpty ? 'My routine' : _name.text.trim(),
      exercises: List.of(_exercises),
      activityKind: _kind,
      source: 'user',
    );
    if (existingId != null) {
      await ref.read(workoutLibraryProvider.notifier).updateCustom(routine);
    } else {
      await ref.read(workoutLibraryProvider.notifier).addCustomRoutine(routine);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Routine saved.')),
    );
    context.go('/workouts');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionScaffold(
      title: widget.routineId == null ? 'Create Routine' : 'Edit Routine',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Routine name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButton<WorkoutActivityKind>(
            value: _kind,
            isExpanded: true,
            items: [
              for (final kind in WorkoutActivityKind.values)
                DropdownMenuItem(value: kind, child: Text(kind.label)),
            ],
            onChanged: (v) => setState(() => _kind = v ?? _kind),
          ),
          const SizedBox(height: 12),
          Text('Exercises', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final name in ExerciseCatalog.names.take(8))
                ActionChip(
                  label: Text(name),
                  onPressed: () => _addExercise(name),
                ),
              ActionChip(
                label: const Text('Custom'),
                onPressed: () => _addExercise('Custom exercise'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_exercises.isEmpty)
            const EmptyMetricCard(
              title: 'No exercises yet',
              message: 'Add exercises, then set sets, reps, duration, weight, and rest.',
            )
          else
            for (var i = 0; i < _exercises.length; i++)
              _ExerciseEditor(
                exercise: _exercises[i],
                onChanged: (ex) => setState(() => _exercises[i] = ex),
                onRemove: () => setState(() => _exercises.removeAt(i)),
                onUp: i == 0
                    ? null
                    : () => setState(() {
                          final item = _exercises.removeAt(i);
                          _exercises.insert(i - 1, item);
                        }),
                onDown: i == _exercises.length - 1
                    ? null
                    : () => setState(() {
                          final item = _exercises.removeAt(i);
                          _exercises.insert(i + 1, item);
                        }),
              ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: const Text('Save routine'),
          ),
        ],
      ),
    );
  }
}

class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({
    required this.exercise,
    required this.onChanged,
    required this.onRemove,
    this.onUp,
    this.onDown,
  });

  final WorkoutExercise exercise;
  final ValueChanged<WorkoutExercise> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(exercise.name)),
                IconButton(onPressed: onUp, icon: const Icon(Icons.arrow_upward)),
                IconButton(onPressed: onDown, icon: const Icon(Icons.arrow_downward)),
                IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                _Num(
                  label: 'Sets',
                  value: exercise.sets,
                  onChanged: (v) => onChanged(exercise.copyWith(sets: v.clamp(1, 12))),
                ),
                _Num(
                  label: 'Reps',
                  value: exercise.reps ?? 0,
                  onChanged: (v) => onChanged(
                    exercise.copyWith(reps: v <= 0 ? null : v, clearReps: v <= 0),
                  ),
                ),
                _Num(
                  label: 'Sec',
                  value: exercise.durationSeconds ?? 0,
                  onChanged: (v) => onChanged(
                    exercise.copyWith(
                      durationSeconds: v <= 0 ? null : v,
                      clearDuration: v <= 0,
                    ),
                  ),
                ),
                _Num(
                  label: 'Kg',
                  value: (exercise.weightKg ?? 0).round(),
                  onChanged: (v) => onChanged(
                    exercise.copyWith(
                      weightKg: v <= 0 ? null : v.toDouble(),
                      clearWeight: v <= 0,
                    ),
                  ),
                ),
                _Num(
                  label: 'Rest',
                  value: exercise.restSeconds,
                  onChanged: (v) =>
                      onChanged(exercise.copyWith(restSeconds: v.clamp(0, 300))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(value - 1),
          icon: const Icon(Icons.remove, size: 16),
        ),
        Text('$value'),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add, size: 16),
        ),
      ],
    );
  }
}
