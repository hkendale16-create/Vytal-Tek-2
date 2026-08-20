import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/fitness_hub_models.dart';
import '../../domain/models/workout_models.dart';
import '../../fitness/calendar_controller.dart';
import '../../fitness/gym_discovery_controller.dart';
import '../../state/app_session_controller.dart';
import '../../workouts/exercise_library.dart';
import '../../workouts/workout_controllers.dart';
import '../ai/coach_vital_engine.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../shared/vytal_controls.dart';
import 'upgrade_prompts.dart';

enum _BuilderGoal {
  strength,
  hypertrophy,
  conditioning,
  general,
  calisthenics,
}

enum _Experience { beginner, intermediate, advanced }

enum _WhereTrain { home, savedGym, nearby, custom }

extension on _BuilderGoal {
  String get label => switch (this) {
        _BuilderGoal.strength => 'Strength',
        _BuilderGoal.hypertrophy => 'Muscle',
        _BuilderGoal.conditioning => 'Conditioning',
        _BuilderGoal.general => 'General fitness',
        _BuilderGoal.calisthenics => 'Calisthenics',
      };

  String get promptHint => switch (this) {
        _BuilderGoal.strength => 'strength full body',
        _BuilderGoal.hypertrophy => 'chest hypertrophy',
        _BuilderGoal.conditioning => 'hiit conditioning',
        _BuilderGoal.general => 'full body workout',
        _BuilderGoal.calisthenics => 'calisthenics bodyweight',
      };
}

class AiWorkoutBuilderScreen extends ConsumerStatefulWidget {
  const AiWorkoutBuilderScreen({super.key});

  @override
  ConsumerState<AiWorkoutBuilderScreen> createState() =>
      _AiWorkoutBuilderScreenState();
}

class _AiWorkoutBuilderScreenState
    extends ConsumerState<AiWorkoutBuilderScreen> {
  var _step = 0;
  var _goal = _BuilderGoal.general;
  var _experience = _Experience.intermediate;
  var _daysPerWeek = 3;
  var _sessionMinutes = 40;
  var _where = _WhereTrain.home;
  var _paywallDismissed = false;
  WorkoutRoutine? _generated;
  SavedGym? _selectedGym;

  @override
  Widget build(BuildContext context) {
    final canUse = ref
        .watch(appSessionProvider)
        .entitlements
        .canUse(EntitlementKeys.aiWorkoutBuilder);

    if (!canUse && !_paywallDismissed) {
      return SectionScaffold(
        title: 'AI Workout Builder',
        subtitle: 'Vytal Pro · helps you train smarter.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'BUILD A PLAN AROUND YOU',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                          color: VytalColors.teal,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Vytal Pro can create training programs around your goals, '
                    'schedule, available equipment, and workout history.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ContextualUpgradeSheet.showAiBuilder(context),
              child: const Text('Try Vytal Pro'),
            ),
            TextButton(
              onPressed: () => setState(() => _paywallDismissed = true),
              child: const Text('Not Now'),
            ),
          ],
        ),
      );
    }

    return SectionScaffold(
      title: 'AI Workout Builder',
      subtitle: 'Goal → experience → schedule → place → generate.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!canUse)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassPanel(
                child: Text(
                  'Preview mode — generating a session still needs '
                  '${EntitlementKeys.displayName(EntitlementKeys.aiWorkoutBuilder)}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          _StepDots(step: _step, total: 5),
          const SizedBox(height: 16),
          if (_generated != null) ...[
            _GeneratedPreview(
              routine: _generated!,
              onSave: _saveToLibrary,
              onCalendar: _addToCalendar,
              onStart: _startWorkout,
              onReset: () => setState(() {
                _generated = null;
                _step = 0;
              }),
            ),
          ] else ...[
            switch (_step) {
              0 => _GoalStep(
                  selected: _goal,
                  onChanged: (g) => setState(() => _goal = g),
                ),
              1 => _ExperienceStep(
                  selected: _experience,
                  onChanged: (e) => setState(() => _experience = e),
                ),
              2 => _ScheduleStep(
                  days: _daysPerWeek,
                  minutes: _sessionMinutes,
                  onDays: (d) => setState(() => _daysPerWeek = d),
                  onMinutes: (m) => setState(() => _sessionMinutes = m),
                ),
              3 => _WhereStep(
                  selected: _where,
                  selectedGym: _selectedGym,
                  onChanged: (w) => setState(() => _where = w),
                  onGym: (g) => setState(() => _selectedGym = g),
                ),
              _ => _ReviewStep(
                  goal: _goal,
                  experience: _experience,
                  days: _daysPerWeek,
                  minutes: _sessionMinutes,
                  where: _where,
                  gym: _selectedGym,
                  equipment: _equipmentLabels(),
                ),
            },
            const SizedBox(height: 16),
            Row(
              children: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _step -= 1),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                if (_step < 4)
                  FilledButton(
                    onPressed: () => setState(() => _step += 1),
                    child: const Text('Next'),
                  )
                else
                  FilledButton(
                    onPressed: canUse ? _generate : _promptUpgrade,
                    child: const Text('Generate'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<String> _equipmentLabels() {
    if (_where == _WhereTrain.home) {
      return ref
          .read(homeGymProvider)
          .equipment
          .map((e) => e.label)
          .toList();
    }
    if (_selectedGym != null) {
      return _selectedGym!.effectiveEquipment.map((e) => e.label).toList();
    }
    return const [];
  }

  void _promptUpgrade() {
    setState(() => _paywallDismissed = false);
  }

  void _generate() {
    final equipment = _equipmentLabels();
    final prompt =
        'Build me a $_sessionMinutes-minute ${_goal.promptHint} workout'
        '${equipment.isEmpty ? '' : ' using ${equipment.take(4).join(', ')}'}.';

    WorkoutRoutine routine;
    try {
      routine = const CoachVitalEngine().buildStructuredWorkout(
        prompt,
        session: ref.read(appSessionProvider),
      );
    } catch (_) {
      routine = _fallbackRoutine(equipment);
    }

    if (equipment.isNotEmpty) {
      final filtered = _filterByEquipment(routine, equipment);
      if (filtered.exercises.isNotEmpty) routine = filtered;
    }

    setState(() => _generated = routine.copyWith(
          name: '${_goal.label} · $_sessionMinutes min',
          source: 'ai',
        ));
  }

  WorkoutRoutine _fallbackRoutine(List<String> equipment) {
    final uuid = const Uuid();
    var catalog = [...ExerciseLibrary.all];
    if (equipment.isNotEmpty) {
      final lower = equipment.map((e) => e.toLowerCase()).toList();
      final filtered = catalog.where((e) {
        final eq = e.equipment.toLowerCase();
        if (eq.contains('bodyweight') || eq == 'none') return true;
        return lower.any((item) =>
            eq.contains(item.toLowerCase()) ||
            item.toLowerCase().contains(eq));
      }).toList();
      if (filtered.isNotEmpty) catalog = filtered;
    }
    final take = (_sessionMinutes / 12).round().clamp(3, 6);
    final picked = catalog.take(take).toList();
    return WorkoutRoutine(
      id: uuid.v4(),
      name: 'Custom session · $_sessionMinutes min',
      activityKind: _goal == _BuilderGoal.calisthenics
          ? WorkoutActivityKind.calisthenics
          : WorkoutActivityKind.strength,
      source: 'ai',
      exercises: [for (final def in picked) def.toExercise()],
    );
  }

  WorkoutRoutine _filterByEquipment(
    WorkoutRoutine routine,
    List<String> equipment,
  ) {
    final lower = equipment.map((e) => e.toLowerCase()).toList();
    final kept = routine.exercises.where((e) {
      final eq = (e.equipment ?? '').toLowerCase();
      if (eq.isEmpty || eq.contains('bodyweight') || eq == 'none') return true;
      return lower.any(
        (item) => eq.contains(item) || item.contains(eq),
      );
    }).toList();
    return routine.copyWith(exercises: kept);
  }

  Future<void> _saveToLibrary() async {
    final routine = _generated;
    if (routine == null) return;
    final saved =
        await ref.read(workoutLibraryProvider.notifier).addCustomRoutine(
              routine.copyWith(builtIn: false, source: 'ai'),
            );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? 'Could not save — custom workouts may be locked.'
              : 'Saved to library',
        ),
      ),
    );
  }

  Future<void> _addToCalendar() async {
    final routine = _generated;
    if (routine == null) return;
    final now = DateTime.now();
    await ref.read(fitnessCalendarProvider.notifier).scheduleWorkout(
          title: routine.name,
          date: DateTime(now.year, now.month, now.day),
          kind: FitnessEventKind.scheduledWorkout,
          timeOfDayMinutes: now.hour * 60 + now.minute,
          durationMinutes: _sessionMinutes,
          routineId: routine.id,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to calendar')),
    );
  }

  Future<void> _startWorkout() async {
    final routine = _generated;
    if (routine == null) return;
    var toStart = routine;
    final missing = ref
        .read(workoutLibraryProvider)
        .routines
        .where((r) => r.id == routine.id)
        .isEmpty;
    if (missing) {
      final saved =
          await ref.read(workoutLibraryProvider.notifier).addCustomRoutine(
                routine.copyWith(builtIn: false, source: 'ai'),
              );
      if (saved != null) toStart = saved;
    }
    if (!mounted) return;
    ref.read(workoutSessionProvider.notifier).startRoutine(toStart);
    context.push('/workouts/active');
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: i <= step
                    ? VytalColors.teal
                    : context.vytalExtras.border,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.selected, required this.onChanged});

  final _BuilderGoal selected;
  final ValueChanged<_BuilderGoal> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VytalSectionHeader(
          title: 'Goal',
          subtitle: 'What should this session emphasize?',
        ),
        for (final goal in _BuilderGoal.values) ...[
          _SelectTile(
            label: goal.label,
            selected: selected == goal,
            onTap: () => onChanged(goal),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ExperienceStep extends StatelessWidget {
  const _ExperienceStep({required this.selected, required this.onChanged});

  final _Experience selected;
  final ValueChanged<_Experience> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VytalSectionHeader(title: 'Experience'),
        for (final e in _Experience.values) ...[
          _SelectTile(
            label: e.name[0].toUpperCase() + e.name.substring(1),
            selected: selected == e,
            onTap: () => onChanged(e),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({
    required this.days,
    required this.minutes,
    required this.onDays,
    required this.onMinutes,
  });

  final int days;
  final int minutes;
  final ValueChanged<int> onDays;
  final ValueChanged<int> onMinutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VytalSectionHeader(title: 'Days per week'),
        VytalTabSelector<int>(
          values: const [2, 3, 4, 5, 6],
          selected: days,
          labelOf: (d) => '$d',
          onChanged: onDays,
        ),
        const SizedBox(height: 16),
        const VytalSectionHeader(title: 'Session length'),
        GlassPanel(
          child: Column(
            children: [
              Text(
                '$minutes min',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Slider(
                value: minutes.toDouble(),
                min: 20,
                max: 90,
                divisions: 14,
                label: '$minutes min',
                onChanged: (v) => onMinutes(v.round()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhereStep extends ConsumerWidget {
  const _WhereStep({
    required this.selected,
    required this.selectedGym,
    required this.onChanged,
    required this.onGym,
  });

  final _WhereTrain selected;
  final SavedGym? selectedGym;
  final ValueChanged<_WhereTrain> onChanged;
  final ValueChanged<SavedGym?> onGym;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeGymProvider);
    final saved = ref.watch(gymDiscoveryProvider).saved;
    final extras = context.vytalExtras;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VytalSectionHeader(title: 'Where will you train?'),
        for (final w in _WhereTrain.values) ...[
          _SelectTile(
            label: switch (w) {
              _WhereTrain.home => 'Home',
              _WhereTrain.savedGym => 'Saved Gym',
              _WhereTrain.nearby => 'Nearby',
              _WhereTrain.custom => 'Custom',
            },
            selected: selected == w,
            onTap: () => onChanged(w),
          ),
          const SizedBox(height: 8),
        ],
        if (selected == _WhereTrain.home) ...[
          const SizedBox(height: 4),
          Text(
            home.isEmpty
                ? 'No home equipment set — bodyweight options will be used.'
                : 'Using: ${home.equipment.map((e) => e.label).join(', ')}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: extras.textMuted),
          ),
          TextButton(
            onPressed: () => context.push('/fitness/home-gym'),
            child: const Text('Edit home gym'),
          ),
        ],
        if (selected == _WhereTrain.savedGym) ...[
          if (saved.isEmpty)
            Text(
              'No saved gyms yet. Save one from Gyms Near Me.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: extras.textMuted),
            )
          else
            for (final g in saved) ...[
              _SelectTile(
                label: g.place.name,
                selected: selectedGym?.place.id == g.place.id,
                onTap: () => onGym(g),
              ),
              const SizedBox(height: 8),
              Text(
                g.hasReliableEquipment
                    ? '${g.effectiveEquipment.length} confirmed items'
                    : 'Equipment not confirmed',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: extras.textMuted),
              ),
              const SizedBox(height: 8),
            ],
        ],
        if (selected == _WhereTrain.nearby)
          HudStrip(
            icon: Icons.place_outlined,
            title: 'Find a gym',
            subtitle: 'Open Gyms Near Me',
            onTap: () => context.push('/fitness/gyms'),
          ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.goal,
    required this.experience,
    required this.days,
    required this.minutes,
    required this.where,
    required this.gym,
    required this.equipment,
  });

  final _BuilderGoal goal;
  final _Experience experience;
  final int days;
  final int minutes;
  final _WhereTrain where;
  final SavedGym? gym;
  final List<String> equipment;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _kv(context, 'Goal', goal.label),
          _kv(
            context,
            'Experience',
            experience.name[0].toUpperCase() + experience.name.substring(1),
          ),
          _kv(context, 'Days / week', '$days'),
          _kv(context, 'Session', '$minutes min'),
          _kv(
            context,
            'Where',
            switch (where) {
              _WhereTrain.home => 'Home',
              _WhereTrain.savedGym => gym?.place.name ?? 'Saved gym',
              _WhereTrain.nearby => 'Nearby gym',
              _WhereTrain.custom => 'Custom',
            },
          ),
          const SizedBox(height: 8),
          Text(
            equipment.isEmpty
                ? 'Equipment: bodyweight / open floor'
                : 'Equipment: ${equipment.join(', ')}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: extras.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(v, style: Theme.of(context).textTheme.titleSmall),
          ),
        ],
      ),
    );
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: GlassPanel(
          glow: selected,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: Theme.of(context).textTheme.titleSmall),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? VytalColors.teal : context.vytalExtras.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneratedPreview extends StatelessWidget {
  const _GeneratedPreview({
    required this.routine,
    required this.onSave,
    required this.onCalendar,
    required this.onStart,
    required this.onReset,
  });

  final WorkoutRoutine routine;
  final VoidCallback onSave;
  final VoidCallback onCalendar;
  final VoidCallback onStart;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          glow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(routine.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${routine.exercises.length} exercises · ${routine.activityKind.label}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: extras.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final e in routine.exercises) ...[
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        [
                          if (e.muscleGroup != null) e.muscleGroup!.label,
                          if (e.equipment != null) e.equipment!,
                        ].join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: extras.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  e.reps != null
                      ? '${e.sets}×${e.reps}'
                      : '${e.sets}×${e.durationSeconds ?? 0}s',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        FilledButton(onPressed: onStart, child: const Text('Start')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onSave,
          child: const Text('Save to library'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onCalendar,
          child: const Text('Add to calendar'),
        ),
        TextButton(onPressed: onReset, child: const Text('Build another')),
      ],
    );
  }
}
