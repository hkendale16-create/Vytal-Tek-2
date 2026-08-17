import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/time/duration_format.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/workout_models.dart';
import '../../state/app_session_controller.dart';
import '../../timers/clock_controllers.dart';
import '../../workouts/exercise_library.dart';
import '../../workouts/workout_controllers.dart';
import '../../workouts/workout_metrics.dart';
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
              child: HudStrip(
                icon: Icons.play_circle_outline,
                title: session.summaryPending
                    ? 'View workout summary'
                    : 'Resume active workout',
                subtitle: 'Session continues if you leave this screen',
                onTap: () => context.push(
                  session.summaryPending ? '/workouts/summary' : '/workouts/active',
                ),
              ),
            ),
          HudActionRail(
            actions: [
              HudAction(
                icon: Icons.play_arrow_rounded,
                label: 'Start',
                onTap: () => context.push('/workouts/start'),
              ),
              HudAction(
                icon: Icons.history,
                label: 'History',
                onTap: () => context.push('/workouts/history'),
              ),
              HudAction(
                icon: Icons.timer_outlined,
                label: 'Timers',
                onTap: () => context.push('/timers'),
              ),
              HudAction(
                icon: Icons.playlist_add,
                label: 'Create',
                onTap: canCustom
                    ? () => context.push('/workouts/builder')
                    : () => context.push('/settings/subscription'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          HudStrip(
            icon: Icons.accessibility_new_outlined,
            title: 'Muscle groups',
            subtitle: 'Chest, back, legs, and more',
            onTap: () => context.push('/workouts/muscles'),
          ),
          const SizedBox(height: 16),
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
                  onPressed: () => context.go('/ask'),
                  child: const Text('Ask Vytal to build a workout'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Workout Tools', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.timer_outlined,
            title: 'Timer',
            subtitle: 'Countdown that keeps running if you leave',
            onTap: () => context.push('/timers/countdown'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.timer_outlined,
            title: 'Stopwatch',
            subtitle: 'Laps without a separate tab',
            onTap: () => context.push('/timers/stopwatch'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.av_timer,
            title: 'Interval timer',
            subtitle: 'Work / rest rounds',
            onTap: () => context.push('/timers/interval'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.self_improvement_outlined,
            title: 'Rest timer',
            subtitle: '1:30 rest preset',
            onTap: () {
              final clock = ref.read(countdownProvider.notifier);
              clock.setHours(0);
              clock.setMinutes(1);
              clock.setSeconds(30);
              context.push('/timers/countdown');
            },
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
      subtitle: 'Each activity has its own metrics and controls.',
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
                    if (kind == WorkoutActivityKind.strength) {
                      context.push('/workouts/muscles');
                      return;
                    }
                    ref.read(workoutSessionProvider.notifier).startActivity(kind);
                    context.push('/workouts/active');
                  },
                  child: GlassPanel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kind.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _activityHint(kind),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
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

  String _activityHint(WorkoutActivityKind kind) => switch (kind) {
        WorkoutActivityKind.running => 'Time, pace, HR zone, steps',
        WorkoutActivityKind.walking => 'Steps, pace, active minutes',
        WorkoutActivityKind.cycling => 'Speed, HR zones, cadence when available',
        WorkoutActivityKind.strength => 'Sets, reps, muscle groups, rest timer',
        WorkoutActivityKind.hiit => 'Work / rest intervals and rounds',
        WorkoutActivityKind.cardio => 'Configurable cardio metrics',
        WorkoutActivityKind.custom => 'Build your own metric mix',
      };
}

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    final health = ref.watch(todayHealthProvider).valueOrNull;
    final theme = Theme.of(context);
    final phase = session.currentPhase;
    final kind = session.activityKind ?? WorkoutActivityKind.custom;
    final hr =
        health?.heartRate.hasValue == true ? health!.heartRate.value : null;
    ref.listen(todayHealthProvider, (previous, next) {
      final sample = next.valueOrNull?.heartRate;
      if (sample != null && sample.hasValue && session.running) {
        ref.read(workoutSessionProvider.notifier).recordHeartRate(sample.value);
      }
    });

    final idle = session.playMode == WorkoutPlayMode.idle &&
        session.phases.isEmpty &&
        !session.summaryPending;
    if (idle) {
      return const SectionScaffold(
        title: 'Workout',
        child: EmptyMetricCard(
          title: 'No active workout',
          message: 'Start a workout from Today or Workouts.',
        ),
      );
    }

    if (session.summaryPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/workouts/summary');
      });
    }

    final display = session.playMode == WorkoutPlayMode.routine &&
            phase != null &&
            phase.kind != WorkoutTimerKind.activity
        ? session.remainingNow()
        : session.elapsedSeconds();
    final weight = ref.watch(appSessionProvider).profile.weightKg ?? 70;
    final calories = WorkoutMetricCatalog.estimatedCalories(
      kind: kind,
      elapsedSeconds: session.elapsedSeconds(),
      weightKg: weight,
    );

    return SectionScaffold(
      title: session.routine?.name ?? kind.label,
      subtitle: session.running ? 'Active' : 'Paused',
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
                  'Elapsed ${formatClock(session.elapsedSeconds())}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _WorkoutMetricsGrid(
            kind: kind,
            session: session,
            hr: hr,
            hrProvenance: health?.heartRate.provenance,
            calories: calories,
            steps: health?.steps,
            phase: phase,
          ),
          const SizedBox(height: 12),
          if (kind == WorkoutActivityKind.strength) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: session.phases.isEmpty
                      ? null
                      : () => ref
                          .read(workoutSessionProvider.notifier)
                          .completeSet(),
                  child: const Text('Complete Set'),
                ),
                OutlinedButton(
                  onPressed: () => ref
                      .read(workoutSessionProvider.notifier)
                      .addSetToCurrentExercise(),
                  child: const Text('Add set'),
                ),
                OutlinedButton(
                  onPressed: () => _addExercise(context),
                  child: const Text('Add exercise'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else if (session.playMode == WorkoutPlayMode.routine) ...[
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () =>
                      ref.read(workoutSessionProvider.notifier).completeSet(),
                  child: const Text('Complete interval'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(workoutSessionProvider.notifier).skip(),
                  child: const Text('Skip'),
                ),
              ],
            ),
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
                  child: Text(
                    session.running
                        ? 'Pause'
                        : (session.elapsedSeconds() == 0 ? 'Start' : 'Resume'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(workoutSessionProvider.notifier).stopAndSummarize();
                    context.push('/workouts/summary');
                  },
                  child: const Text('Stop'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () async {
              if (session.hasProgress) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset workout?'),
                    content: const Text(
                      'Elapsed time and session metrics will return to zero. Saved history is not deleted.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
              }
              ref.read(workoutSessionProvider.notifier).resetSession();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _addExercise(BuildContext context) async {
    final choice = await showModalBottomSheet<ExerciseDefinition>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            for (final item in ExerciseLibrary.all)
              ListTile(
                title: Text(item.name),
                subtitle: Text('${item.muscleGroup.label} · ${item.equipment}'),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        );
      },
    );
    if (choice == null) return;
    ref.read(workoutSessionProvider.notifier).addExerciseToSession(
          choice.toExercise(),
        );
  }
}

class _WorkoutMetricsGrid extends StatelessWidget {
  const _WorkoutMetricsGrid({
    required this.kind,
    required this.session,
    required this.hr,
    required this.hrProvenance,
    required this.calories,
    required this.steps,
    required this.phase,
  });

  final WorkoutActivityKind kind;
  final WorkoutSessionState session;
  final int? hr;
  final DataProvenance? hrProvenance;
  final int calories;
  final int? steps;
  final TimerPhase? phase;

  @override
  Widget build(BuildContext context) {
    final ids = WorkoutMetricCatalog.forKind(kind);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in ids)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 56) / 2,
            child: _tile(id),
          ),
      ],
    );
  }

  Widget _tile(WorkoutMetricId id) {
    switch (id) {
      case WorkoutMetricId.elapsed:
        return MetricHudTile(
          title: 'Elapsed',
          value: formatClock(session.elapsedSeconds()),
          emptyMessage: '0:00',
        );
      case WorkoutMetricId.distance:
        return const MetricHudTile(
          title: 'Distance',
          emptyMessage: 'Unavailable without GPS',
        );
      case WorkoutMetricId.pace:
        return const MetricHudTile(
          title: 'Pace',
          emptyMessage: 'Needs distance',
        );
      case WorkoutMetricId.speed:
        return const MetricHudTile(
          title: 'Speed',
          emptyMessage: 'Needs distance',
        );
      case WorkoutMetricId.heartRate:
        return MetricHudTile(
          title: 'Heart Rate',
          value: hr?.toString(),
          unit: 'BPM',
          emptyMessage: 'No connected reading',
          provenance: hrProvenance,
        );
      case WorkoutMetricId.hrZone:
        return MetricHudTile(
          title: 'HR zone',
          value: WorkoutMetricCatalog.hrZoneLabel(hr),
          emptyMessage: 'Needs live HR',
        );
      case WorkoutMetricId.calories:
        return MetricHudTile(
          title: 'Calories',
          value: calories == 0 ? null : '$calories',
          unit: 'est. kcal',
          emptyMessage: 'Estimate after you start',
        );
      case WorkoutMetricId.cadence:
        return const MetricHudTile(
          title: 'Cadence',
          emptyMessage: 'Not reported by this device',
        );
      case WorkoutMetricId.steps:
        return MetricHudTile(
          title: 'Steps',
          value: steps?.toString(),
          emptyMessage: 'No step reading',
        );
      case WorkoutMetricId.activeMinutes:
        return MetricHudTile(
          title: 'Active min',
          value: '${(session.elapsedSeconds() / 60).floor()}',
        );
      case WorkoutMetricId.exercise:
        return MetricHudTile(
          title: 'Exercise',
          value: phase?.exerciseName,
          emptyMessage: 'Add an exercise',
        );
      case WorkoutMetricId.muscleGroup:
        return MetricHudTile(
          title: 'Muscle',
          value: phase?.muscleGroup?.label,
          emptyMessage: '—',
        );
      case WorkoutMetricId.sets:
        final setNumber = phase?.setNumber;
        final setsTotal = phase?.setsTotal;
        return MetricHudTile(
          title: 'Set',
          value: setNumber == null
              ? null
              : '$setNumber/${setsTotal ?? setNumber}',
          emptyMessage: '—',
        );
      case WorkoutMetricId.reps:
        return MetricHudTile(
          title: 'Reps',
          value: phase?.reps?.toString(),
          emptyMessage: '—',
        );
      case WorkoutMetricId.weight:
        final kg = phase?.weightKg;
        return MetricHudTile(
          title: 'Weight',
          value: kg == null
              ? null
              : '${WorkoutMetricCatalog.kgToLb(kg).round()} lb',
          emptyMessage: '—',
        );
      case WorkoutMetricId.rest:
        return MetricHudTile(
          title: 'Rest',
          value: phase?.kind == WorkoutTimerKind.rest
              ? formatClock(session.remainingNow())
              : null,
          emptyMessage: 'Work set',
        );
      case WorkoutMetricId.volume:
        var volume = 0.0;
        for (final ex
            in session.routine?.exercises ?? const <WorkoutExercise>[]) {
          if (ex.weightKg != null && ex.reps != null) {
            volume += ex.weightKg! * ex.reps! * ex.sets;
          }
        }
        return MetricHudTile(
          title: 'Volume',
          value: volume == 0 ? null : volume.round().toString(),
          unit: 'kg',
          emptyMessage: 'Add weighted sets',
        );
      case WorkoutMetricId.workInterval:
        return MetricHudTile(
          title: 'Work',
          value: '${session.hiitWorkSeconds}s',
        );
      case WorkoutMetricId.restInterval:
        return MetricHudTile(
          title: 'Rest interval',
          value: '${session.hiitRestSeconds}s',
        );
      case WorkoutMetricId.round:
        final round = phase?.setNumber;
        final total = phase?.setsTotal ?? session.hiitRounds;
        return MetricHudTile(
          title: 'Round',
          value: round == null ? null : '$round/$total',
          emptyMessage: '—',
        );
      case WorkoutMetricId.intervalTimer:
        return MetricHudTile(
          title: 'Interval',
          value: formatClock(session.remainingNow()),
        );
    }
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
                Text(
                  'Estimated calories ${WorkoutMetricCatalog.estimatedCalories(
                    kind: session.activityKind ?? WorkoutActivityKind.custom,
                    elapsedSeconds: session.elapsedSeconds(),
                    weightKg: ref.watch(appSessionProvider).profile.weightKg ?? 70,
                  )} kcal (app estimate, not a wearable reading).',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
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
            onPressed: () => context.push(
              '/notes?category=workout&record=${session.routine?.id ?? 'session'}',
            ),
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
      final draft = ref.read(pendingRoutineDraftProvider);
      if (draft != null && widget.routineId == null) {
        setState(() {
          _name.text = draft.name;
          _kind = draft.activityKind;
          _exercises
            ..clear()
            ..addAll(draft.exercises);
        });
        ref.read(pendingRoutineDraftProvider.notifier).state = null;
        return;
      }
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
    final def = ExerciseLibrary.byName(name);
    setState(() {
      _exercises.add(
        def?.toExercise() ??
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
              for (final name in ExerciseCatalog.names)
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
