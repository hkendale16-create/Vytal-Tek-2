import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/permissions/permission_catalog.dart';
import '../../core/permissions/permission_prompt.dart';
import '../../core/theme/vytal_colors.dart';
import '../../core/time/duration_format.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/workout_models.dart';
import '../../state/app_session_controller.dart';
import '../../workouts/exercise_library.dart';
import '../../workouts/phone_gps.dart';
import '../../workouts/workout_controllers.dart';
import '../../workouts/workout_gps.dart';
import '../../workouts/workout_metrics.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../shared/vytal_controls.dart';
import '../subscription/soft_paywall.dart';
import '../today/today_health_provider.dart';
import 'activity_motion.dart';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  var _category = WorkoutHubCategory.strength;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(workoutLibraryProvider);
    final session = ref.watch(workoutSessionProvider);
    final history = ref.watch(workoutHistoryProvider);
    final canCustom = ref
        .watch(appSessionProvider)
        .entitlements
        .canUse(EntitlementKeys.workoutsCustom);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Workouts',
      actions: [
        IconButton(
          tooltip: 'History',
          onPressed: () => context.push('/workouts/history'),
          icon: const Icon(Icons.history),
        ),
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
                  session.summaryPending
                      ? '/workouts/summary'
                      : '/workouts/active',
                ),
              ),
            ),
          VytalTabSelector<WorkoutHubCategory>(
            values: WorkoutHubCategory.values,
            selected: _category,
            labelOf: _hubLabel,
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 16),
          switch (_category) {
            WorkoutHubCategory.cardio => _CardioHub(
                library: library,
                canCustom: canCustom,
              ),
            WorkoutHubCategory.strength => _StrengthHub(
                library: library,
                canCustom: canCustom,
              ),
            WorkoutHubCategory.calisthenics => _CalisthenicsHub(
                library: library,
                canCustom: canCustom,
              ),
          },
          const SizedBox(height: 16),
          HudStrip(
            icon: Icons.timer_outlined,
            title: 'Timers',
            subtitle: 'Countdown, stopwatch, intervals, and rest',
            onTap: () => context.push('/timers'),
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

  static String _hubLabel(WorkoutHubCategory category) => switch (category) {
        WorkoutHubCategory.cardio => 'Cardio',
        WorkoutHubCategory.strength => 'Strength',
        WorkoutHubCategory.calisthenics => 'Calisthenics',
      };
}

class _CardioHub extends ConsumerWidget {
  const _CardioHub({required this.library, required this.canCustom});

  final WorkoutLibraryState library;
  final bool canCustom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = _routinesFor(library, WorkoutHubCategory.cardio);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VytalSectionHeader(
          title: 'Activities',
          subtitle: 'Outdoor GPS stays on this phone. Indoor cardio never invents sensors.',
        ),
        for (final kind in WorkoutActivityKindX.cardioKinds) ...[
          _ActivityTile(
            kind: kind,
            onTap: () => startChosenWorkout(context, ref, kind),
          ),
          const SizedBox(height: 10),
        ],
        const VytalSectionHeader(title: 'My Workouts'),
        _MyWorkoutsSection(
          routines: routines,
          canCustom: canCustom,
          emptyMessage: 'Save a HIIT or cardio routine to see it here.',
        ),
      ],
    );
  }
}

class _StrengthHub extends ConsumerWidget {
  const _StrengthHub({required this.library, required this.canCustom});

  final WorkoutLibraryState library;
  final bool canCustom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mine = _routinesFor(library, WorkoutHubCategory.strength);
    final builtIn = library.builtIn
        .where((r) => r.activityKind.hubCategory == WorkoutHubCategory.strength)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HudActionRail(
          actions: [
            HudAction(
              icon: Icons.flash_on_outlined,
              label: 'Quick Start',
              onTap: () => startChosenWorkout(
                context,
                ref,
                WorkoutActivityKind.strength,
                quickStart: true,
              ),
            ),
            HudAction(
              icon: Icons.playlist_add,
              label: 'Create',
              onTap: canCustom
                  ? () => context.push('/workouts/builder')
                  : () => context.push('/settings/subscription'),
            ),
            HudAction(
              icon: Icons.play_arrow_rounded,
              label: 'Start',
              onTap: () => context.push('/workouts/start'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        HudStrip(
          icon: Icons.accessibility_new_outlined,
          title: 'Muscle groups',
          subtitle: 'Chest, back, legs, and more',
          onTap: () => context.push('/workouts/muscles'),
        ),
        const SizedBox(height: 16),
        const VytalSectionHeader(title: 'My Workouts'),
        _MyWorkoutsSection(
          routines: mine,
          canCustom: canCustom,
          emptyMessage:
              'Create a routine or ask Vytal to build one you can start here.',
        ),
        if (builtIn.isNotEmpty) ...[
          const SizedBox(height: 8),
          const VytalSectionHeader(title: 'Vytal routines'),
          for (final routine in builtIn) ...[
            _RoutineCard(
              routine: routine,
              onStart: () {
                ref.read(workoutSessionProvider.notifier).startRoutine(routine);
                context.push('/workouts/active');
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
        const VytalSectionHeader(title: 'Ask Vytal'),
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
      ],
    );
  }
}

class _CalisthenicsHub extends ConsumerWidget {
  const _CalisthenicsHub({required this.library, required this.canCustom});

  final WorkoutLibraryState library;
  final bool canCustom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = _routinesFor(library, WorkoutHubCategory.calisthenics);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HudActionRail(
          actions: [
            HudAction(
              icon: Icons.flash_on_outlined,
              label: 'Quick Start',
              onTap: () => startChosenWorkout(
                context,
                ref,
                WorkoutActivityKind.calisthenics,
                quickStart: true,
              ),
            ),
            HudAction(
              icon: Icons.playlist_add,
              label: 'Create',
              onTap: canCustom
                  ? () => context.push(
                        '/workouts/builder?kind=${WorkoutActivityKind.calisthenics.name}',
                      )
                  : () => context.push('/settings/subscription'),
            ),
            HudAction(
              icon: Icons.history,
              label: 'History',
              onTap: () => context.push('/workouts/history'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const VytalSectionHeader(
          title: 'Catalog',
          subtitle: 'Holds use duration. Weighted moves keep reps and load.',
        ),
        for (final def in ExerciseLibrary.calisthenics) ...[
          _CalisthenicsTile(
            definition: def,
            onStart: () {
              final session = ref.read(workoutSessionProvider.notifier);
              session.startStrengthDraft(
                name: def.name,
                kind: WorkoutActivityKind.calisthenics,
              );
              session.addExerciseToSession(def.toExercise());
              context.push('/workouts/active');
            },
          ),
          const SizedBox(height: 10),
        ],
        const VytalSectionHeader(title: 'My Workouts'),
        _MyWorkoutsSection(
          routines: mine,
          canCustom: canCustom,
          emptyMessage: 'Save a bodyweight routine to reuse it here.',
        ),
      ],
    );
  }
}

class _MyWorkoutsSection extends ConsumerWidget {
  const _MyWorkoutsSection({
    required this.routines,
    required this.canCustom,
    required this.emptyMessage,
  });

  final List<WorkoutRoutine> routines;
  final bool canCustom;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canCustom) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: SoftPaywall(
          entitlementKey: EntitlementKeys.workoutsCustom,
          compact: true,
        ),
      );
    }
    if (routines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: EmptyMetricCard(
          title: 'No workouts yet',
          message: emptyMessage,
        ),
      );
    }
    return Column(
      children: [
        for (final routine in routines) ...[
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
            onDuplicate: () async {
              final saved = await ref
                  .read(workoutLibraryProvider.notifier)
                  .duplicateCustom(routine.id);
              if (saved == null && context.mounted) {
                context.push('/settings/subscription');
              }
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

List<WorkoutRoutine> _routinesFor(
  WorkoutLibraryState library,
  WorkoutHubCategory category,
) {
  return library.custom
      .where((routine) => routine.activityKind.hubCategory == category)
      .toList(growable: false);
}

IconData _activityIcon(WorkoutActivityKind kind) => switch (kind) {
      WorkoutActivityKind.running || WorkoutActivityKind.treadmill =>
        Icons.directions_run,
      WorkoutActivityKind.walking => Icons.directions_walk,
      WorkoutActivityKind.cycling || WorkoutActivityKind.elliptical =>
        Icons.directions_bike,
      WorkoutActivityKind.stairClimber => Icons.stairs,
      WorkoutActivityKind.rowing => Icons.sports,
      WorkoutActivityKind.jumpRope => Icons.skip_next_outlined,
      WorkoutActivityKind.strength => Icons.fitness_center,
      WorkoutActivityKind.calisthenics => Icons.self_improvement_outlined,
      WorkoutActivityKind.hiit => Icons.bolt,
      WorkoutActivityKind.cardio || WorkoutActivityKind.custom =>
        Icons.monitor_heart_outlined,
    };

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.kind, required this.onTap});

  final WorkoutActivityKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: GlassPanel(
          child: Row(
            children: [
              Icon(_activityIcon(kind), color: VytalColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kind.label, style: theme.textTheme.titleMedium),
                    Text(kind.hubHint, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalisthenicsTile extends StatelessWidget {
  const _CalisthenicsTile({
    required this.definition,
    required this.onStart,
  });

  final ExerciseDefinition definition;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(definition.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${definition.muscleGroup.label} · ${definition.prescriptionLabel}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onStart,
            child: const Text('Start'),
          ),
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
    this.onDuplicate,
  });

  final WorkoutRoutine routine;
  final VoidCallback onStart;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = routine.muscleGroupSummary;
    final summary = [
      '${routine.exercises.length} exercise${routine.exercises.length == 1 ? '' : 's'}',
      if (groups.isNotEmpty) groups.take(3).join(', '),
      if (routine.estimatedMinutes > 0) '~${routine.estimatedMinutes} min',
      routine.activityKind.label,
    ].join(' · ');
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
                const StatusPill(label: 'Ask Vytal', emphasis: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(summary, style: theme.textTheme.bodySmall),
          if (routine.notes != null && routine.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(routine.notes!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: onStart,
                child: const Text('Start'),
              ),
              if (onEdit != null)
                OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              if (onDuplicate != null)
                OutlinedButton(
                  onPressed: onDuplicate,
                  child: const Text('Duplicate'),
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: VytalColors.alert,
                ),
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
    final theme = Theme.of(context);
    return SectionScaffold(
      title: 'Start Workout',
      subtitle: 'Same catalog as the Workout hub — each activity keeps its own metrics.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const VytalSectionHeader(title: 'Cardio'),
          for (final kind in WorkoutActivityKindX.cardioKinds) ...[
            _ActivityTile(
              kind: kind,
              onTap: () => startChosenWorkout(context, ref, kind),
            ),
            const SizedBox(height: 10),
          ],
          const VytalSectionHeader(title: 'Strength'),
          _ActivityTile(
            kind: WorkoutActivityKind.strength,
            onTap: () => startChosenWorkout(
              context,
              ref,
              WorkoutActivityKind.strength,
            ),
          ),
          const SizedBox(height: 10),
          const VytalSectionHeader(title: 'Calisthenics'),
          _ActivityTile(
            kind: WorkoutActivityKind.calisthenics,
            onTap: () => startChosenWorkout(
              context,
              ref,
              WorkoutActivityKind.calisthenics,
              quickStart: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quick Start opens an empty logger so you can add exercises live.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

Future<void> startChosenWorkout(
  BuildContext context,
  WidgetRef ref,
  WorkoutActivityKind kind, {
  bool quickStart = false,
}) async {
  if (kind.usesStrengthSets) {
    if (kind == WorkoutActivityKind.strength && !quickStart) {
      context.push('/workouts/muscles');
      return;
    }
    ref.read(workoutSessionProvider.notifier).startStrengthDraft(
          name: kind.label,
          kind: kind,
        );
    context.push('/workouts/active');
    return;
  }
  if (kind == WorkoutActivityKind.hiit) {
    final config = await _showHiitSetupSheet(context);
    if (config == null || !context.mounted) return;
    ref.read(workoutSessionProvider.notifier).startHiit(
          workSeconds: config.work,
          restSeconds: config.rest,
          rounds: config.rounds,
        );
    context.push('/workouts/active');
    return;
  }
  List<WorkoutMetricId>? metrics;
  if (kind == WorkoutActivityKind.cardio ||
      kind == WorkoutActivityKind.custom) {
    metrics = await showMetricPickerSheet(context, kind);
    if (metrics == null || !context.mounted) return;
  }
  var gpsDenied = false;
  final wantsGps = WorkoutMetricCatalog.usesPhoneGps(kind) ||
      (metrics?.any(WorkoutMetricCatalog.needsGps) ?? false);
  if (wantsGps && PhoneGps.supported && context.mounted) {
    final explained = await ensureVytalPermission(
      context: context,
      ref: ref,
      item: PermissionCatalog.location,
      headline: 'Use location for this workout?',
      explanation:
          'Vytal can measure distance, pace, and a local route sketch from this phone. The track stays on-device and is not uploaded.',
    );
    var granted = explained;
    if (granted) {
      granted = await PhoneGps.requestPermission();
    }
    gpsDenied = !granted;
  }
  if (!context.mounted) return;
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      (kind == WorkoutActivityKind.walking ||
          kind == WorkoutActivityKind.running)) {
    unawaited(
      ensureVytalPermission(
        context: context,
        ref: ref,
        item: PermissionCatalog.activity,
        headline: 'Allow activity for step tracking?',
        explanation:
            'Physical activity permission helps session steps where Android requires it. You can skip this and still run the workout.',
      ),
    );
  }
  final steps = ref.read(todayHealthProvider).valueOrNull?.steps;
  ref.read(workoutSessionProvider.notifier).startActivity(
        kind,
        enabledMetrics: metrics,
        baselineSteps: steps,
        gpsDenied: gpsDenied,
      );
  if (!gpsDenied && wantsGps && PhoneGps.supported) {
    unawaited(
      ref.read(workoutSessionProvider.notifier).listenGps(PhoneGps.watch()),
    );
  }
  if (context.mounted) context.push('/workouts/active');
}

class _HiitSetup {
  const _HiitSetup({
    required this.work,
    required this.rest,
    required this.rounds,
  });
  final int work;
  final int rest;
  final int rounds;
}

Future<_HiitSetup?> _showHiitSetupSheet(BuildContext context) async {
  var work = 40;
  var rest = 20;
  var rounds = 8;
  return showModalBottomSheet<_HiitSetup>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('HIIT setup', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _Num(
                  label: 'Work sec',
                  value: work,
                  onChanged: (v) => setSheet(() => work = v.clamp(5, 180)),
                ),
                _Num(
                  label: 'Rest sec',
                  value: rest,
                  onChanged: (v) => setSheet(() => rest = v.clamp(5, 180)),
                ),
                _Num(
                  label: 'Rounds',
                  value: rounds,
                  onChanged: (v) => setSheet(() => rounds = v.clamp(1, 30)),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _HiitSetup(work: work, rest: rest, rounds: rounds),
                  ),
                  child: const Text('Start HIIT'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<List<WorkoutMetricId>?> showMetricPickerSheet(
  BuildContext context,
  WorkoutActivityKind kind,
) async {
  final selected = {
    WorkoutMetricId.elapsed,
    ...WorkoutMetricCatalog.forKind(kind),
  };
  return showModalBottomSheet<List<WorkoutMetricId>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${kind.label} metrics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Elapsed is always shown. Distance, pace, and speed need phone GPS.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                for (final id in WorkoutMetricCatalog.configurableIds)
                  CheckboxListTile(
                    value: selected.contains(id),
                    title: Text(WorkoutMetricCatalog.labelFor(id)),
                    onChanged: (v) {
                      setSheet(() {
                        if (v == true) {
                          selected.add(id);
                        } else {
                          selected.remove(id);
                        }
                      });
                    },
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    [
                      WorkoutMetricId.elapsed,
                      ...selected.where((id) => id != WorkoutMetricId.elapsed),
                    ],
                  ),
                  child: Text('Start ${kind.label}'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

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
            phase: phase,
          ),
          if (session.routePoints.length >= 2) ...[
            const SizedBox(height: 8),
            _RouteSketch(points: session.routePoints),
          ],
          const SizedBox(height: 12),
          if (kind.usesStrengthSets) ...[
            if (phase != null && phase.kind == WorkoutTimerKind.exercise)
              _LiveSetEditor(phase: phase),
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

class _LiveSetEditor extends ConsumerWidget {
  const _LiveSetEditor({required this.phase});

  final TimerPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lb = phase.weightKg == null
        ? 0
        : WorkoutMetricCatalog.kgToLb(phase.weightKg!).round();
    final timedHold =
        phase.reps == null && phase.kind == WorkoutTimerKind.exercise;
    final equipment = (phase.equipment ?? '').toLowerCase();
    final showWeight = phase.weightKg != null ||
        (equipment.isNotEmpty && equipment != 'bodyweight' && !timedHold);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (timedHold)
              _Num(
                label: 'Sec',
                value: phase.seconds,
                onChanged: (v) => ref
                    .read(workoutSessionProvider.notifier)
                    .updateCurrentSet(durationSeconds: v.clamp(5, 600)),
              )
            else
              _Num(
                label: 'Reps',
                value: phase.reps ?? 0,
                onChanged: (v) => ref
                    .read(workoutSessionProvider.notifier)
                    .updateCurrentSet(reps: v),
              ),
            if (showWeight)
              _Num(
                label: 'lb',
                value: lb,
                onChanged: (v) => ref
                    .read(workoutSessionProvider.notifier)
                    .updateCurrentSet(
                      weightKg: v <= 0
                          ? 0
                          : WorkoutMetricCatalog.lbToKg(v.toDouble()),
                    ),
              ),
            _Num(
              label: 'Rest',
              value: phase.kind == WorkoutTimerKind.rest
                  ? phase.seconds
                  : (ref.watch(workoutSessionProvider).nextPhase?.kind ==
                          WorkoutTimerKind.rest
                      ? ref.watch(workoutSessionProvider).nextPhase!.seconds
                      : 60),
              onChanged: (v) => ref
                  .read(workoutSessionProvider.notifier)
                  .updateCurrentSet(restSeconds: v.clamp(0, 300)),
            ),
          ],
        ),
      ),
    );
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
          emptyMessage: session.gpsDenied
              ? 'Location off'
              : 'Waiting for GPS',
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
                  'Avg HR ${session.averageHr ?? '—'} · Max HR ${session.maxHr ?? '—'}'
                  '${session.distanceMeters > 0 ? ' · ${formatDistanceKm(session.distanceMeters)}' : ''}',
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
                            '${entry.activityKind.label} · ${formatClock(entry.durationSeconds)}'
                            '${entry.distanceMeters != null ? ' · ${formatDistanceKm(entry.distanceMeters!)}' : ''}',
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
  const RoutineBuilderScreen({super.key, this.routineId, this.initialKind});

  final String? routineId;
  final WorkoutActivityKind? initialKind;

  @override
  ConsumerState<RoutineBuilderScreen> createState() =>
      _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends ConsumerState<RoutineBuilderScreen> {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _exercises = <WorkoutExercise>[];
  late WorkoutActivityKind _kind;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialKind ?? WorkoutActivityKind.strength;
    _kind = WorkoutActivityKindX.builderKinds.contains(initial)
        ? initial
        : WorkoutActivityKind.strength;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draft = ref.read(pendingRoutineDraftProvider);
      if (draft != null && widget.routineId == null) {
        setState(() {
          _name.text = draft.name;
          _notes.text = draft.notes ?? '';
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
        _notes.text = match.notes ?? '';
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
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
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
            value: WorkoutActivityKindX.builderKinds.contains(_kind)
                ? _kind
                : WorkoutActivityKind.custom,
            isExpanded: true,
            items: [
              for (final kind in WorkoutActivityKindX.builderKinds)
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
              for (final def in _kind == WorkoutActivityKind.calisthenics
                  ? ExerciseLibrary.calisthenics
                  : ExerciseLibrary.all)
                ActionChip(
                  label: Text(def.name),
                  onPressed: () => _addExercise(def.name),
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
