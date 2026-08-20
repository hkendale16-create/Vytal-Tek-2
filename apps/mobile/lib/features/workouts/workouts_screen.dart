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
import '../today/training_guidance.dart';
import 'first_session_panel.dart';
import 'ring_connect_prompt.dart';
import 'workout_history_ui.dart';

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
    final readiness = ref.watch(todayHealthProvider).valueOrNull?.readinessScore;

    return SectionScaffold(
      title: 'Workout',
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
          if (history.entries.isEmpty &&
              !(session.running || session.summaryPending || session.completed)) ...[
            const FirstSessionPanel(compact: true),
            const SizedBox(height: 12),
          ],
          const VytalSectionHeader(
            title: 'Train',
            subtitle: 'Quick Start, routines, and plans.',
          ),
          HudStrip(
            icon: Icons.flash_on_outlined,
            title: 'Quick Start',
            subtitle: 'Empty logger — add exercises live',
            onTap: () => startChosenWorkout(
              context,
              ref,
              WorkoutActivityKind.strength,
              quickStart: true,
            ),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.view_week_outlined,
            title: 'Plans',
            subtitle: 'Build muscle, strength, conditioning, home',
            onTap: () => context.push('/fitness/plans'),
          ),
          const SizedBox(height: 16),
          const VytalSectionHeader(
            title: 'Plan',
            subtitle: 'Calendar and AI builder.',
          ),
          HudStrip(
            icon: Icons.calendar_month_outlined,
            title: 'Calendar',
            subtitle: 'Week view · scheduled & completed sessions',
            onTap: () => context.push('/fitness/calendar'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.auto_awesome_outlined,
            title: 'AI Workout Builder',
            subtitle: 'Goal · experience · equipment-aware',
            onTap: () => context.push('/fitness/ai-builder'),
          ),
          const SizedBox(height: 16),
          const VytalSectionHeader(
            title: 'Discover',
            subtitle: 'Exercises and gyms near you.',
          ),
          HudStrip(
            icon: Icons.search_outlined,
            title: 'Exercises',
            subtitle: 'Library, filters, alternatives',
            onTap: () => context.push('/fitness/exercises'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.location_on_outlined,
            title: 'Gyms Near Me',
            subtitle: 'Location optional · list first',
            onTap: () => context.push('/fitness/gyms'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.home_outlined,
            title: 'My Home Gym',
            subtitle: 'Equipment you own',
            onTap: () => context.push('/fitness/home-gym'),
          ),
          const SizedBox(height: 16),
          const VytalSectionHeader(
            title: 'Review',
            subtitle: 'History and progress — no wearable required.',
          ),
          HudStrip(
            icon: Icons.history,
            title: 'History',
            subtitle: 'Past sessions and set logs',
            onTap: () => context.push('/workouts/history'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.insights_outlined,
            title: 'Progress',
            subtitle: 'Volume, consistency, strength PRs',
            onTap: () => context.push('/fitness/progress'),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt_outlined, color: VytalColors.teal, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    TrainingGuidance.workoutHubHint(readiness),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
            const VytalSectionHeader(
              title: 'Recent',
              subtitle: 'Tap a session for set logs and details.',
            ),
            for (final entry in history.entries.take(3))
              WorkoutHistoryTile(
                entry: entry,
                onTap: () => showWorkoutHistoryDetail(context, entry),
              ),
            if (history.entries.length > 3)
              TextButton(
                onPressed: () => context.push('/workouts/history'),
                child: Text('View all ${history.entries.length} sessions'),
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
        const VytalSectionHeader(title: 'Training plans'),
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
                child: const Text('Build a workout plan'),
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
    final history = ref.watch(workoutHistoryProvider).entries;
    final theme = Theme.of(context);
    final readiness = ref.watch(todayHealthProvider).valueOrNull?.readinessScore;
    if (session.phases.isEmpty && !session.summaryPending && !session.completed) {
      return const SectionScaffold(
        title: 'Summary',
        child: EmptyMetricCard(
          title: 'No workout to save',
          message: 'Finish a session to see time, heart rate, and notes.',
        ),
      );
    }

    final candidateVolume = session.setLogs.fold<double>(0, (sum, log) {
      if (!log.completed || !log.setType.countsForVolume) return sum;
      if (log.weightKg == null || log.reps == null) return sum;
      return sum + log.weightKg! * log.reps!;
    });
    final candidate = WorkoutHistoryEntry(
      id: 'pending-summary',
      name: session.routine?.name ?? 'Workout',
      activityKind: session.activityKind ?? WorkoutActivityKind.custom,
      durationSeconds: session.elapsedSeconds(),
      completedAt: DateTime.now().toUtc(),
      distanceMeters:
          session.distanceMeters <= 0 ? null : session.distanceMeters,
      trainingVolumeKg: candidateVolume == 0 ? null : candidateVolume,
      setLogs: session.setLogs.where((log) => log.completed).toList(),
    );
    final records = TrainingGuidance.personalRecordsBroken(
      candidate: candidate,
      history: history,
    );
    final streak = TrainingGuidance.currentStreakDays([
      candidate,
      ...history,
    ]);

    return SectionScaffold(
      title: 'Workout summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            glow: true,
            child: Column(
              children: [
                Text(
                  'Session complete',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.6,
                    color: VytalColors.teal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(session.routine?.name ?? 'Workout',
                    style: theme.textTheme.titleLarge),
                Text(
                  formatClock(session.elapsedSeconds()),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: VytalColors.teal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  TrainingGuidance.postWorkoutTip(readiness),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                if (streak > 0) ...[
                  const SizedBox(height: 10),
                  StatusPill(
                    label: streak == 1
                        ? '1 day streak started'
                        : '$streak day streak',
                    emphasis: true,
                  ),
                ],
                const SizedBox(height: 8),
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
          if (records.isNotEmpty) ...[
            const SizedBox(height: 12),
            const VytalSectionHeader(title: 'Personal records'),
            GlassPanel(
              glow: true,
              accent: VytalColors.teal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final record in records)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_outlined,
                            color: VytalColors.teal,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              record.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            record.detail,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: VytalColors.teal,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (session.setLogs.any((log) => log.completed)) ...[
            const SizedBox(height: 12),
            const VytalSectionHeader(title: 'Sets'),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final log in session.setLogs.where((l) => l.completed))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${log.exerciseName} · ${log.summary}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ],
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
              await maybeOfferRingConnect(context: context, ref: ref);
              if (!context.mounted) return;
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
                  WorkoutHistoryTile(
                    entry: entry,
                    onTap: () => showWorkoutHistoryDetail(context, entry),
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
