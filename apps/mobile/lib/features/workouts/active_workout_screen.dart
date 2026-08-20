import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../core/time/duration_format.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/workout_models.dart';
import '../../state/app_session_controller.dart';
import '../../workouts/exercise_library.dart';
import '../../workouts/phone_gps.dart';
import '../../workouts/workout_controllers.dart';
import '../../workouts/workout_metrics.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../today/today_health_provider.dart';
import 'activity_motion.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureGps());
  }

  Future<void> _ensureGps() async {
    final session = ref.read(workoutSessionProvider);
    final kind = session.activityKind;
    if (kind == null || session.gpsDenied || session.gpsActive) return;
    final wantsGps = WorkoutMetricCatalog.usesPhoneGps(kind) ||
        (session.enabledMetrics?.any(WorkoutMetricCatalog.needsGps) ?? false);
    if (!wantsGps || !PhoneGps.supported) return;
    final granted = await PhoneGps.requestPermission();
    if (!mounted) return;
    if (!granted) {
      ref.read(workoutSessionProvider.notifier).markGpsDenied();
      return;
    }
    await ref.read(workoutSessionProvider.notifier).listenGps(PhoneGps.watch());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    final health = ref.watch(todayHealthProvider).valueOrNull;
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

    final weight = ref.watch(appSessionProvider).profile.weightKg ?? 70;
    final calories = WorkoutMetricCatalog.estimatedCalories(
      kind: kind,
      elapsedSeconds: session.elapsedSeconds(),
      weightKg: weight,
    );

    return SectionScaffold(
      title: session.routine?.name ?? kind.label,
      subtitle: session.running ? 'Active' : 'Paused',
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              formatClock(session.elapsedSeconds()),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: VytalColors.teal,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ),
        IconButton(
          tooltip: session.running ? 'Pause' : 'Resume',
          onPressed: () {
            final n = ref.read(workoutSessionProvider.notifier);
            if (session.running) {
              n.pause();
            } else {
              n.resume();
            }
          },
          icon: Icon(session.running ? Icons.pause : Icons.play_arrow),
        ),
        TextButton(
          onPressed: () {
            ref.read(workoutSessionProvider.notifier).stopAndSummarize();
            context.push('/workouts/summary');
          },
          child: const Text('Finish'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session.isResting) ...[
            _RestBanner(
              remaining: session.remainingNow(),
              onSkip: () =>
                  ref.read(workoutSessionProvider.notifier).skipRest(),
            ),
            const SizedBox(height: 12),
          ],
          if (session.usesSetLogger)
            _StrengthLogger(
              session: session,
              hr: hr,
              hrProvenance: health?.heartRate.provenance,
              onAddExercise: () => _addExercise(context),
            )
          else
            _CardioLogger(
              kind: kind,
              session: session,
              phase: phase,
              hr: hr,
              hrProvenance: health?.heartRate.provenance,
              calories: calories,
            ),
          const SizedBox(height: 8),
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
    final kind = ref.read(workoutSessionProvider).activityKind;
    final catalog = kind == WorkoutActivityKind.calisthenics
        ? ExerciseLibrary.calisthenics
        : ExerciseLibrary.all;
    final choice = await showModalBottomSheet<ExerciseDefinition>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            for (final item in catalog)
              ListTile(
                title: Text(item.name),
                subtitle: Text(
                  '${item.muscleGroup.label} · ${item.prescriptionLabel}',
                ),
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

class _RestBanner extends StatelessWidget {
  const _RestBanner({required this.remaining, required this.onSkip});

  final int remaining;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      glow: true,
      accent: VytalColors.caution,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REST',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: VytalColors.caution,
                  ),
                ),
                Text(
                  formatClock(remaining),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: VytalColors.caution,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onSkip,
            child: const Text('Skip rest'),
          ),
        ],
      ),
    );
  }
}

class _StrengthLogger extends ConsumerWidget {
  const _StrengthLogger({
    required this.session,
    required this.hr,
    required this.hrProvenance,
    required this.onAddExercise,
  });

  final WorkoutSessionState session;
  final int? hr;
  final DataProvenance? hrProvenance;
  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = session.routine?.exercises ?? const <WorkoutExercise>[];
    final volume = session.setLogs.fold<double>(0, (sum, log) {
      if (!log.completed || !log.setType.countsForVolume) return sum;
      if (log.weightKg == null || log.reps == null) return sum;
      return sum + log.weightKg! * log.reps!;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 56) / 2,
              child: MetricHudTile(
                title: 'Heart Rate',
                value: hr?.toString(),
                unit: 'BPM',
                emptyMessage: 'No connected reading',
                provenance: hrProvenance,
              ),
            ),
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 56) / 2,
              child: MetricHudTile(
                title: 'Volume',
                value: volume == 0 ? null : volume.round().toString(),
                unit: 'kg',
                emptyMessage: 'Complete weighted sets',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (exercises.isEmpty)
          const EmptyMetricCard(
            title: 'No exercises yet',
            message: 'Quick Start is empty until you add a movement to log.',
          )
        else
          for (final exercise in exercises) ...[
            _ExerciseLoggerCard(exercise: exercise, session: session),
            const SizedBox(height: 10),
          ],
        FilledButton.icon(
          onPressed: onAddExercise,
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
      ],
    );
  }
}

class _ExerciseLoggerCard extends ConsumerWidget {
  const _ExerciseLoggerCard({
    required this.exercise,
    required this.session,
  });

  final WorkoutExercise exercise;
  final WorkoutSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final sets = <(int, TimerPhase)>[];
    for (var i = 0; i < session.phases.length; i++) {
      final phase = session.phases[i];
      if (phase.kind == WorkoutTimerKind.exercise &&
          phase.exerciseId == exercise.id) {
        sets.add((i, phase));
      }
    }
    final timed = sets.any((item) => item.$2.isTimedHold);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(exercise.name, style: theme.textTheme.titleMedium),
          Text(
            [
              if (exercise.muscleGroup != null) exercise.muscleGroup!.label,
              if (exercise.equipment != null) exercise.equipment!,
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text('SET', style: theme.textTheme.labelSmall),
              ),
              Expanded(
                child: Text(
                  'PREV',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: extras.textMuted,
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  timed ? 'SEC' : 'LB',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  timed ? '' : 'REPS',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 6),
          for (var row = 0; row < sets.length; row++)
            _SetRow(
              index: sets[row].$1,
              phase: sets[row].$2,
              previous: row == 0 ? null : sets[row - 1].$2,
              current: session.phaseIndex == sets[row].$1,
              timed: sets[row].$2.isTimedHold,
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref
                  .read(workoutSessionProvider.notifier)
                  .addSetToExercise(exercise.id),
              child: const Text('Add set'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends ConsumerWidget {
  const _SetRow({
    required this.index,
    required this.phase,
    required this.previous,
    required this.current,
    required this.timed,
  });

  final int index;
  final TimerPhase phase;
  final TimerPhase? previous;
  final bool current;
  final bool timed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final lb = phase.weightKg == null
        ? 0
        : WorkoutMetricCatalog.kgToLb(phase.weightKg!).round();
    final prevText = _previousLabel(previous);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: phase.completed
              ? VytalColors.teal.withValues(alpha: 0.08)
              : (current ? extras.elevated : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: InkWell(
                onTap: () =>
                    ref.read(workoutSessionProvider.notifier).cycleSetType(index),
                child: Text(
                  phase.setType == WorkoutSetType.working
                      ? '${phase.setNumber ?? index + 1}'
                      : phase.setType.shortLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: phase.setType == WorkoutSetType.working
                        ? extras.textMuted
                        : VytalColors.teal,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                prevText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: extras.textMuted,
                ),
              ),
            ),
            if (timed)
              SizedBox(
                width: 72,
                child: _MiniStepper(
                  value: phase.seconds,
                  onChanged: (v) => ref
                      .read(workoutSessionProvider.notifier)
                      .updateSetAt(index, durationSeconds: v.clamp(5, 600)),
                ),
              )
            else ...[
              SizedBox(
                width: 72,
                child: _MiniStepper(
                  value: lb,
                  onChanged: (v) =>
                      ref.read(workoutSessionProvider.notifier).updateSetAt(
                            index,
                            weightKg: v <= 0
                                ? 0
                                : WorkoutMetricCatalog.lbToKg(v.toDouble()),
                          ),
                ),
              ),
              SizedBox(
                width: 56,
                child: _MiniStepper(
                  value: phase.reps ?? 0,
                  onChanged: (v) => ref
                      .read(workoutSessionProvider.notifier)
                      .updateSetAt(index, reps: v.clamp(0, 100)),
                ),
              ),
            ],
            SizedBox(
              width: 40,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: phase.completed || !current
                    ? null
                    : () =>
                        ref.read(workoutSessionProvider.notifier).completeSet(),
                icon: Icon(
                  phase.completed
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: phase.completed
                      ? VytalColors.teal
                      : extras.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previousLabel(TimerPhase? previous) {
    if (previous == null || !previous.completed) return '—';
    if (previous.isTimedHold) return '${previous.seconds}s';
    if (previous.weightKg != null && previous.reps != null) {
      return '${WorkoutMetricCatalog.kgToLb(previous.weightKg!).round()}×${previous.reps}';
    }
    if (previous.reps != null) return '${previous.reps} r';
    return '—';
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(value + 1),
      onLongPress: () => onChanged((value - 1).clamp(0, 9999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ),
    );
  }
}

class _CardioLogger extends ConsumerWidget {
  const _CardioLogger({
    required this.kind,
    required this.session,
    required this.phase,
    required this.hr,
    required this.hrProvenance,
    required this.calories,
  });

  final WorkoutActivityKind kind;
  final WorkoutSessionState session;
  final TimerPhase? phase;
  final int? hr;
  final DataProvenance? hrProvenance;
  final int calories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final interval = session.playMode == WorkoutPlayMode.routine &&
        phase != null &&
        phase!.kind != WorkoutTimerKind.activity;
    final display =
        interval ? session.remainingNow() : session.elapsedSeconds();
    return Column(
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
                interval
                    ? 'Elapsed ${formatClock(session.elapsedSeconds())}'
                    : (session.running ? 'Live' : 'Paused'),
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
          hrProvenance: hrProvenance,
          calories: calories,
          phase: phase,
        ),
        if (session.routePoints.length >= 2) ...[
          const SizedBox(height: 8),
          _RouteSketch(points: session.routePoints),
        ],
        const SizedBox(height: 12),
        if (session.playMode == WorkoutPlayMode.routine) ...[
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
      ],
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
    required this.phase,
  });

  final WorkoutActivityKind kind;
  final WorkoutSessionState session;
  final int? hr;
  final DataProvenance? hrProvenance;
  final int calories;
  final TimerPhase? phase;

  @override
  Widget build(BuildContext context) {
    final ids = session.visibleMetrics;
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
        return MetricHudTile(
          title: 'Distance',
          value: session.gpsActive || session.distanceMeters > 0
              ? formatDistanceKm(session.distanceMeters)
              : null,
          emptyMessage:
              session.gpsDenied ? 'Location off' : 'Waiting for GPS',
        );
      case WorkoutMetricId.pace:
        return MetricHudTile(
          title: 'Pace',
          value: formatPace(session.distanceMeters, session.elapsedSeconds()),
          emptyMessage: 'Needs distance',
        );
      case WorkoutMetricId.speed:
        return MetricHudTile(
          title: 'Speed',
          value: formatSpeedKmh(session.currentSpeedMps),
          emptyMessage: 'Needs GPS',
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
        return MetricHudTile(
          title: 'Cadence',
          value: session.cadenceRpm?.toString(),
          unit: 'rpm',
          emptyMessage: 'Not reported by this device',
        );
      case WorkoutMetricId.steps:
        final steps = session.sessionSteps;
        final fromGps = session.distanceMeters > 0 &&
            (kind == WorkoutActivityKind.running ||
                kind == WorkoutActivityKind.walking);
        return MetricHudTile(
          title: 'Steps',
          value: steps?.toString(),
          unit: fromGps && steps != null ? 'est.' : '',
          emptyMessage: 'No step reading',
        );
      case WorkoutMetricId.route:
        return MetricHudTile(
          title: 'Route',
          value: session.routePoints.length >= 2 ? 'On device' : null,
          emptyMessage: session.gpsDenied ? 'Location off' : 'Waiting for GPS',
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
          value: setNumber == null ? null : '$setNumber/${setsTotal ?? setNumber}',
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
        return MetricHudTile(
          title: 'Volume',
          value: null,
          emptyMessage: 'Logged on Finish',
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

class _RouteSketch extends StatelessWidget {
  const _RouteSketch({required this.points});

  final List<({double x, double y})> points;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Route', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _RoutePainter(points: points, color: VytalColors.teal),
            ),
          ),
          Text(
            'On-device sketch · not shared',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.points, required this.color});

  final List<({double x, double y})> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final offset = Offset(points[i].x * size.width, points[i].y * size.height);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.points != points;
}
