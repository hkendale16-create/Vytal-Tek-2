import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/fitness_hub_models.dart';
import '../../domain/models/workout_models.dart';
import '../../fitness/equipment_workout_builder.dart';
import '../../fitness/gym_discovery_controller.dart';
import '../../workouts/exercise_library.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../shared/vytal_controls.dart';

/// Browser categories map onto MuscleGroup + cardio/mobility buckets.
enum ExerciseBrowserCategory {
  chest,
  back,
  shoulders,
  arms,
  core,
  legs,
  glutes,
  fullBody,
  cardio,
  mobility,
}

extension on ExerciseBrowserCategory {
  String get label => switch (this) {
        ExerciseBrowserCategory.chest => 'Chest',
        ExerciseBrowserCategory.back => 'Back',
        ExerciseBrowserCategory.shoulders => 'Shoulders',
        ExerciseBrowserCategory.arms => 'Arms',
        ExerciseBrowserCategory.core => 'Core',
        ExerciseBrowserCategory.legs => 'Legs',
        ExerciseBrowserCategory.glutes => 'Glutes',
        ExerciseBrowserCategory.fullBody => 'Full Body',
        ExerciseBrowserCategory.cardio => 'Cardio',
        ExerciseBrowserCategory.mobility => 'Mobility',
      };

  bool matches(ExerciseDefinition def) {
    final g = def.muscleGroup;
    return switch (this) {
      ExerciseBrowserCategory.chest => g == MuscleGroup.chest,
      ExerciseBrowserCategory.back => g == MuscleGroup.back,
      ExerciseBrowserCategory.shoulders => g == MuscleGroup.shoulders,
      ExerciseBrowserCategory.arms =>
        g == MuscleGroup.biceps ||
            g == MuscleGroup.triceps ||
            g == MuscleGroup.forearms,
      ExerciseBrowserCategory.core => g == MuscleGroup.core,
      ExerciseBrowserCategory.legs =>
        g == MuscleGroup.quadriceps ||
            g == MuscleGroup.hamstrings ||
            g == MuscleGroup.calves,
      ExerciseBrowserCategory.glutes => g == MuscleGroup.glutes,
      ExerciseBrowserCategory.fullBody => g == MuscleGroup.fullBody,
      ExerciseBrowserCategory.cardio =>
        g == MuscleGroup.fullBody &&
            (def.name.toLowerCase().contains('burpee') ||
                def.name.toLowerCase().contains('mountain') ||
                def.name.toLowerCase().contains('jumping') ||
                def.name.toLowerCase().contains('swing')),
      ExerciseBrowserCategory.mobility =>
        def.name.toLowerCase().contains('plank') ||
            def.equipment.toLowerCase().contains('band'),
    };
  }
}

const _alternativeMap = <String, List<String>>{
  'Bench Press': [
    'Incline Dumbbell Press',
    'Push-up',
    'Dumbbell Fly',
  ],
  'Incline Dumbbell Press': ['Bench Press', 'Push-up', 'Dumbbell Fly'],
  'Push-up': ['Incline Dumbbell Press', 'Bench Press', 'Pike Push-up'],
  'Pull-up': ['Lat Pulldown', 'Chin-up', 'Dumbbell Row'],
  'Chin-up': ['Pull-up', 'Lat Pulldown', 'Dumbbell Row'],
  'Lat Pulldown': ['Pull-up', 'Chin-up', 'Dumbbell Row'],
  'Deadlift': ['Romanian Deadlift', 'Kettlebell Swing', 'Hip Thrust'],
  'Romanian Deadlift': ['Deadlift', 'Kettlebell Swing', 'Hip Thrust'],
  'Shoulder Press': ['Lateral Raise', 'Pike Push-up', 'Face Pull'],
  'Lateral Raise': ['Shoulder Press', 'Face Pull'],
  'Barbell Row': ['Dumbbell Row', 'Lat Pulldown', 'Pull-up'],
  'Dumbbell Row': ['Barbell Row', 'Lat Pulldown', 'Pull-up'],
  'Bodyweight Squat': ['Goblet Squat', 'Lunges', 'Pistol Squat'],
  'Goblet Squat': ['Bodyweight Squat', 'Lunges', 'Hip Thrust'],
  'Lunges': ['Bodyweight Squat', 'Goblet Squat', 'Glute Bridge'],
  'Hip Thrust': ['Glute Bridge', 'Romanian Deadlift', 'Lunges'],
  'Glute Bridge': ['Hip Thrust', 'Bodyweight Squat', 'Lunges'],
  'Bicep Curl': ['Hammer Curl', 'Chin-up'],
  'Hammer Curl': ['Bicep Curl', 'Chin-up'],
  'Plank': ['Side Plank', 'Sit-up', 'Leg Raise'],
  'Side Plank': ['Plank', 'Sit-up'],
  'Kettlebell Swing': ['Romanian Deadlift', 'Jumping Jack', 'Burpee'],
  'Burpee': ['Mountain Climber', 'Jumping Jack', 'Push-up'],
  'Mountain Climber': ['Burpee', 'Jumping Jack', 'Plank'],
};

String? _inferSecondary(ExerciseDefinition def) {
  return switch (def.muscleGroup) {
    MuscleGroup.chest => 'Triceps · Front delts',
    MuscleGroup.back => 'Biceps · Rear delts',
    MuscleGroup.shoulders => 'Triceps · Upper traps',
    MuscleGroup.biceps => 'Forearms',
    MuscleGroup.triceps => 'Chest · Shoulders',
    MuscleGroup.forearms => 'Grip',
    MuscleGroup.core => 'Hip flexors',
    MuscleGroup.glutes => 'Hamstrings · Core',
    MuscleGroup.quadriceps => 'Glutes · Core',
    MuscleGroup.hamstrings => 'Glutes · Lower back',
    MuscleGroup.calves => 'Ankles',
    MuscleGroup.fullBody => 'Conditioning',
  };
}

enum _DifficultyFilter { all, beginner, intermediate, advanced }

enum _TypeFilter { all, strength, duration, bodyweight }

class ExerciseBrowserScreen extends ConsumerStatefulWidget {
  const ExerciseBrowserScreen({super.key});

  @override
  ConsumerState<ExerciseBrowserScreen> createState() =>
      _ExerciseBrowserScreenState();
}

class _ExerciseBrowserScreenState extends ConsumerState<ExerciseBrowserScreen> {
  final _search = TextEditingController();
  ExerciseBrowserCategory? _category;
  String? _equipment;
  var _difficulty = _DifficultyFilter.all;
  var _type = _TypeFilter.all;
  var _matchHomeGym = false;
  ExerciseDefinition? _detail;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ExerciseDefinition> get _catalog {
    final seen = <String>{};
    final out = <ExerciseDefinition>[];
    for (final e in [...ExerciseLibrary.all, ...ExerciseLibrary.calisthenics]) {
      if (seen.add(e.name.toLowerCase())) out.add(e);
    }
    return out;
  }

  List<String> get _equipmentOptions {
    final set = _catalog.map((e) => e.equipment).toSet().toList()..sort();
    return set;
  }

  List<ExerciseDefinition> _filtered(List<GymEquipmentItem> homeEquipment) {
    final q = _search.text.trim().toLowerCase();
    return _catalog.where((e) {
      if (q.isNotEmpty && !e.name.toLowerCase().contains(q)) return false;
      if (_category != null && !_category!.matches(e)) return false;
      if (_equipment != null && e.equipment != _equipment) return false;
      if (_matchHomeGym &&
          homeEquipment.isNotEmpty &&
          !EquipmentWorkoutBuilder.exerciseMatchesEquipment(
            e.equipment,
            homeEquipment,
          )) {
        return false;
      }
      if (_type == _TypeFilter.duration && !e.usesDuration) return false;
      if (_type == _TypeFilter.strength && e.usesDuration) return false;
      if (_type == _TypeFilter.bodyweight &&
          !e.equipment.toLowerCase().contains('bodyweight') &&
          e.equipment.toLowerCase() != 'none') {
        return false;
      }
      if (_difficulty != _DifficultyFilter.all) {
        final hard = e.name.toLowerCase().contains('weighted') ||
            e.name.toLowerCase().contains('pistol') ||
            e.name.toLowerCase().contains('muscle-up') ||
            e.name.toLowerCase().contains('handstand');
        final easy = e.equipment.toLowerCase().contains('bodyweight') &&
            (e.defaultReps ?? 0) >= 10;
        if (_difficulty == _DifficultyFilter.advanced && !hard) return false;
        if (_difficulty == _DifficultyFilter.beginner && (hard || !easy)) {
          return false;
        }
        if (_difficulty == _DifficultyFilter.intermediate && (hard || easy)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_detail != null) {
      return _ExerciseDetailView(
        exercise: _detail!,
        onBack: () => setState(() => _detail = null),
        onOpenAlternative: (name) {
          final match = _catalog.where((e) => e.name == name);
          if (match.isNotEmpty) setState(() => _detail = match.first);
        },
      );
    }

    final extras = context.vytalExtras;
    final home = ref.watch(homeGymProvider);
    final results = _filtered(home.equipment);

    return SectionScaffold(
      title: 'Exercises',
      subtitle: 'Browse by muscle, equipment, and type.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search exercises',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Match my home gym'),
            subtitle: Text(
              home.isEmpty
                  ? 'Set equipment in My Home Gym to enable'
                  : 'Only show moves that fit ${home.equipment.length} items',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: extras.textMuted),
            ),
            value: _matchHomeGym && !home.isEmpty,
            onChanged: home.isEmpty
                ? null
                : (v) => setState(() => _matchHomeGym = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null,
                    showCheckmark: false,
                    selectedColor: VytalColors.teal.withValues(alpha: 0.16),
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final cat in ExerciseBrowserCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat.label),
                      selected: _category == cat,
                      showCheckmark: false,
                      selectedColor: VytalColors.teal.withValues(alpha: 0.16),
                      onSelected: (_) => setState(() => _category = cat),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _equipment,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Equipment',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any')),
                    for (final eq in _equipmentOptions)
                      DropdownMenuItem(value: eq, child: Text(eq)),
                  ],
                  onChanged: (v) => setState(() => _equipment = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<_DifficultyFilter>(
                  initialValue: _difficulty,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    isDense: true,
                  ),
                  items: [
                    for (final d in _DifficultyFilter.values)
                      DropdownMenuItem(
                        value: d,
                        child: Text(switch (d) {
                          _DifficultyFilter.all => 'Any',
                          _DifficultyFilter.beginner => 'Beginner',
                          _DifficultyFilter.intermediate => 'Intermediate',
                          _DifficultyFilter.advanced => 'Advanced',
                        }),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => _difficulty = v ?? _DifficultyFilter.all),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          VytalTabSelector<_TypeFilter>(
            values: _TypeFilter.values,
            selected: _type,
            labelOf: (t) => switch (t) {
              _TypeFilter.all => 'Type',
              _TypeFilter.strength => 'Strength',
              _TypeFilter.duration => 'Timed',
              _TypeFilter.bodyweight => 'Bodyweight',
            },
            onChanged: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: 14),
          Text(
            '${results.length} exercise${results.length == 1 ? '' : 's'}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: extras.textMuted),
          ),
          const SizedBox(height: 8),
          for (final e in results) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _detail = e),
                child: GlassPanel(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              '${e.muscleGroup.label} · ${e.equipment}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: extras.textMuted),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(label: e.prescriptionLabel),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ExerciseDetailView extends StatelessWidget {
  const _ExerciseDetailView({
    required this.exercise,
    required this.onBack,
    required this.onOpenAlternative,
  });

  final ExerciseDefinition exercise;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenAlternative;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final secondary = _inferSecondary(exercise);
    final catalogNames = {
      for (final e in [...ExerciseLibrary.all, ...ExerciseLibrary.calisthenics])
        e.name,
    };
    final alts = (_alternativeMap[exercise.name] ?? const <String>[])
        .where(catalogNames.contains)
        .toList();

    return SectionScaffold(
      title: exercise.name,
      actions: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Primary', style: Theme.of(context).textTheme.labelSmall),
                Text(
                  exercise.muscleGroup.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Secondary',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(secondary, style: Theme.of(context).textTheme.bodyLarge),
                ],
                const SizedBox(height: 10),
                Text(
                  'Equipment',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  exercise.equipment,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 10),
                StatusPill(label: exercise.prescriptionLabel, emphasis: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Move with control through a full range you own. Brace your '
                  'core, keep joints stacked, and stop if form breaks down.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: extras.textMuted),
                ),
              ],
            ),
          ),
          if (alts.isNotEmpty) ...[
            const SizedBox(height: 12),
            const VytalSectionHeader(title: 'Alternatives'),
            for (final alt in alts) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onOpenAlternative(alt),
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            alt,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: extras.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}
