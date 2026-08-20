import 'package:uuid/uuid.dart';

import '../domain/models/fitness_hub_models.dart';
import '../domain/models/workout_models.dart';
import '../workouts/exercise_library.dart';

/// Shared equipment-aware session builder for Gym → Workout Here and AI tools.
///
/// Never claims equipment that was not confirmed by the user or a trusted source.
abstract final class EquipmentWorkoutBuilder {
  static const _uuid = Uuid();

  static List<String> labelsFromItems(List<GymEquipmentItem> items) =>
      items.map((e) => e.label).toList();

  /// Build a structured routine from duration, focus, and equipment labels.
  static WorkoutRoutine build({
    required int minutes,
    required String focus,
    List<String> equipmentLabels = const [],
    String? locationName,
  }) {
    final lower = focus.toLowerCase();
    final groups = <MuscleGroup>[];
    if (lower.contains('upper') || lower.contains('chest') || lower.contains('push')) {
      groups.addAll([MuscleGroup.chest, MuscleGroup.shoulders, MuscleGroup.triceps]);
    } else if (lower.contains('lower') || lower.contains('leg')) {
      groups.addAll([
        MuscleGroup.quadriceps,
        MuscleGroup.hamstrings,
        MuscleGroup.glutes,
        MuscleGroup.calves,
      ]);
    } else if (lower.contains('cardio') || lower.contains('condition')) {
      return _cardio(minutes, locationName);
    } else if (lower.contains('pull') || lower.contains('back')) {
      groups.addAll([MuscleGroup.back, MuscleGroup.biceps]);
    } else {
      groups.addAll([
        MuscleGroup.chest,
        MuscleGroup.back,
        MuscleGroup.quadriceps,
        MuscleGroup.core,
      ]);
    }

    final take = (minutes / 12).round().clamp(3, 6);
    final picked = <ExerciseDefinition>[];
    for (final group in groups) {
      var catalog = ExerciseLibrary.forGroup(group);
      catalog = _filterCatalog(catalog, equipmentLabels);
      for (final ex in catalog) {
        if (picked.any((p) => p.name == ex.name)) continue;
        picked.add(ex);
        if (picked.length >= take) break;
      }
      if (picked.length >= take) break;
    }
    if (picked.isEmpty) {
      picked.addAll(
        _filterCatalog(ExerciseLibrary.forGroup(MuscleGroup.fullBody), equipmentLabels)
            .take(3),
      );
    }
    if (picked.isEmpty) {
      // Absolute fallback — bodyweight only when no gear matches.
      picked.addAll(ExerciseLibrary.forGroup(MuscleGroup.chest).where(
        (e) => e.equipment.toLowerCase().contains('body'),
      ).take(2));
      picked.addAll(ExerciseLibrary.forGroup(MuscleGroup.core).take(1));
    }

    final place = locationName == null || locationName.isEmpty
        ? ''
        : ' · $locationName';
    return WorkoutRoutine(
      id: _uuid.v4(),
      name: '$minutes-min $focus$place',
      activityKind: WorkoutActivityKind.strength,
      source: 'equipment',
      exercises: [
        for (final ex in picked.take(take))
          WorkoutExercise(
            id: _uuid.v4(),
            name: ex.name,
            muscleGroup: ex.muscleGroup,
            equipment: ex.equipment,
            sets: ex.defaultSets,
            reps: ex.defaultReps,
            durationSeconds: ex.defaultDurationSeconds,
            restSeconds: ex.defaultRestSeconds,
            weightKg: ex.defaultWeightKg,
          ),
      ],
      notes: equipmentLabels.isEmpty
          ? 'Built without an equipment filter.'
          : 'Filtered to: ${equipmentLabels.take(6).join(', ')}',
    );
  }

  static WorkoutRoutine _cardio(int minutes, String? locationName) {
    final place = locationName == null || locationName.isEmpty
        ? ''
        : ' · $locationName';
    return WorkoutRoutine(
      id: _uuid.v4(),
      name: '$minutes-min Cardio$place',
      activityKind: WorkoutActivityKind.cardio,
      source: 'equipment',
      exercises: [
        WorkoutExercise(
          id: _uuid.v4(),
          name: 'Steady cardio',
          muscleGroup: MuscleGroup.fullBody,
          equipment: 'Cardio machine or outdoors',
          sets: 1,
          durationSeconds: (minutes * 60 * 0.8).round().clamp(60, 5400),
          restSeconds: 0,
        ),
        WorkoutExercise(
          id: _uuid.v4(),
          name: 'Cool-down walk',
          muscleGroup: MuscleGroup.fullBody,
          equipment: 'None',
          sets: 1,
          durationSeconds: (minutes * 60 * 0.2).round().clamp(60, 900),
          restSeconds: 0,
        ),
      ],
    );
  }

  static List<ExerciseDefinition> _filterCatalog(
    List<ExerciseDefinition> catalog,
    List<String> equipmentLabels,
  ) {
    if (equipmentLabels.isEmpty) return catalog;
    final needles = equipmentLabels.map((e) => e.toLowerCase()).toList();
    final bodyweightOk = needles.any(
      (n) =>
          n.contains('no equipment') ||
          n.contains('bodyweight') ||
          n.contains('pull-up') ||
          n.contains('bands'),
    );
    final filtered = catalog.where((ex) {
      final eq = ex.equipment.toLowerCase();
      if (eq.contains('body') || eq.contains('none')) return bodyweightOk || needles.isEmpty;
      return needles.any(
        (n) =>
            eq.contains(n.split(' ').first) ||
            n.contains(eq.split(' ').first) ||
            (eq.contains('dumbbell') && n.contains('dumbbell')) ||
            (eq.contains('barbell') && n.contains('barbell')) ||
            (eq.contains('cable') && n.contains('cable')) ||
            (eq.contains('kettle') && n.contains('kettle')) ||
            (eq.contains('band') && n.contains('band')),
      );
    }).toList();
    return filtered.isEmpty ? catalog : filtered;
  }

  /// Soften: drop one accessory, reduce sets.
  static WorkoutRoutine makeEasier(WorkoutRoutine routine) {
    if (routine.exercises.isEmpty) return routine;
    final next = [...routine.exercises];
    if (next.length > 3) next.removeLast();
    return routine.copyWith(
      name: '${routine.name} (easier)',
      exercises: [
        for (final ex in next)
          ex.copyWith(sets: (ex.sets - 1).clamp(1, 8)),
      ],
    );
  }

  /// Harden: add a set to compounds.
  static WorkoutRoutine makeHarder(WorkoutRoutine routine) {
    if (routine.exercises.isEmpty) return routine;
    return routine.copyWith(
      name: '${routine.name} (harder)',
      exercises: [
        for (final ex in routine.exercises)
          ex.copyWith(sets: (ex.sets + 1).clamp(1, 8)),
      ],
    );
  }

  /// Shorten: keep first N exercises sized to ~target minutes.
  static WorkoutRoutine shorten(WorkoutRoutine routine, {int targetMinutes = 30}) {
    if (routine.exercises.isEmpty) return routine;
    final keep = (targetMinutes / 12).round().clamp(2, routine.exercises.length);
    return routine.copyWith(
      name: '${routine.name} (short)',
      exercises: routine.exercises.take(keep).toList(),
    );
  }

  /// Replace one exercise with an alternative from the same muscle group.
  static WorkoutRoutine replaceExercise(
    WorkoutRoutine routine,
    String exerciseId,
  ) {
    final index = routine.exercises.indexWhere((e) => e.id == exerciseId);
    if (index < 0) return routine;
    final current = routine.exercises[index];
    final group = current.muscleGroup ?? MuscleGroup.fullBody;
    final alts = ExerciseLibrary.forGroup(group)
        .where((e) => e.name != current.name)
        .toList();
    if (alts.isEmpty) return routine;
    final pick = alts[index % alts.length];
    final next = [...routine.exercises];
    next[index] = current.copyWith(
      name: pick.name,
      muscleGroup: pick.muscleGroup,
      equipment: pick.equipment,
      reps: pick.defaultReps,
      restSeconds: pick.defaultRestSeconds,
    );
    return routine.copyWith(exercises: next);
  }

  /// Whether an exercise string is compatible with owned/home equipment.
  static bool exerciseMatchesEquipment(
    String? equipment,
    List<GymEquipmentItem> owned,
  ) {
    if (owned.isEmpty) return true;
    if (owned.contains(GymEquipmentItem.noEquipment)) {
      final eq = (equipment ?? '').toLowerCase();
      return eq.isEmpty ||
          eq.contains('body') ||
          eq.contains('none') ||
          eq == 'none';
    }
    final labels = labelsFromItems(owned);
    final eq = (equipment ?? '').toLowerCase();
    if (eq.isEmpty || eq.contains('body') || eq.contains('none')) return true;
    return labels.any((label) {
      final n = label.toLowerCase();
      return eq.contains(n.split(' ').first) ||
          n.contains(eq.split(' ').first) ||
          (eq.contains('dumbbell') && n.contains('dumbbell')) ||
          (eq.contains('barbell') && n.contains('barbell')) ||
          (eq.contains('cable') && n.contains('cable')) ||
          (eq.contains('band') && n.contains('band')) ||
          (eq.contains('kettle') && n.contains('kettle'));
    });
  }
}
