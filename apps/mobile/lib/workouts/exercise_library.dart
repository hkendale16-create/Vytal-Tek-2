import 'package:uuid/uuid.dart';

import '../domain/models/workout_models.dart';

/// Catalog of strength exercises grouped by muscle. Names only — not sensor data.
abstract final class ExerciseLibrary {
  static const uuidSeed = 'catalog';

  static List<ExerciseDefinition> get all => const [
        ExerciseDefinition(
          name: 'Bench Press',
          muscleGroup: MuscleGroup.chest,
          equipment: 'Barbell',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 90,
        ),
        ExerciseDefinition(
          name: 'Incline Dumbbell Press',
          muscleGroup: MuscleGroup.chest,
          equipment: 'Dumbbells',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 75,
        ),
        ExerciseDefinition(
          name: 'Push-up',
          muscleGroup: MuscleGroup.chest,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Dumbbell Fly',
          muscleGroup: MuscleGroup.chest,
          equipment: 'Dumbbells',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 60,
        ),
        ExerciseDefinition(
          name: 'Barbell Row',
          muscleGroup: MuscleGroup.back,
          equipment: 'Barbell',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 75,
        ),
        ExerciseDefinition(
          name: 'Dumbbell Row',
          muscleGroup: MuscleGroup.back,
          equipment: 'Dumbbells',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 60,
        ),
        ExerciseDefinition(
          name: 'Lat Pulldown',
          muscleGroup: MuscleGroup.back,
          equipment: 'Cable',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 60,
        ),
        ExerciseDefinition(
          name: 'Pull-up',
          muscleGroup: MuscleGroup.back,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultReps: 6,
          defaultRestSeconds: 90,
        ),
        ExerciseDefinition(
          name: 'Shoulder Press',
          muscleGroup: MuscleGroup.shoulders,
          equipment: 'Dumbbells',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 60,
        ),
        ExerciseDefinition(
          name: 'Lateral Raise',
          muscleGroup: MuscleGroup.shoulders,
          equipment: 'Dumbbells',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Face Pull',
          muscleGroup: MuscleGroup.shoulders,
          equipment: 'Cable',
          defaultSets: 3,
          defaultReps: 15,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Bicep Curl',
          muscleGroup: MuscleGroup.biceps,
          equipment: 'Dumbbells',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Hammer Curl',
          muscleGroup: MuscleGroup.biceps,
          equipment: 'Dumbbells',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Tricep Dip',
          muscleGroup: MuscleGroup.triceps,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Tricep Pushdown',
          muscleGroup: MuscleGroup.triceps,
          equipment: 'Cable',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Wrist Curl',
          muscleGroup: MuscleGroup.forearms,
          equipment: 'Dumbbells',
          defaultSets: 3,
          defaultReps: 15,
          defaultRestSeconds: 30,
        ),
        ExerciseDefinition(
          name: 'Plank',
          muscleGroup: MuscleGroup.core,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultDurationSeconds: 40,
          defaultRestSeconds: 30,
        ),
        ExerciseDefinition(
          name: 'Hanging Knee Raise',
          muscleGroup: MuscleGroup.core,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Cable Crunch',
          muscleGroup: MuscleGroup.core,
          equipment: 'Cable',
          defaultSets: 3,
          defaultReps: 15,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Glute Bridge',
          muscleGroup: MuscleGroup.glutes,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Hip Thrust',
          muscleGroup: MuscleGroup.glutes,
          equipment: 'Barbell',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 75,
        ),
        ExerciseDefinition(
          name: 'Bodyweight Squat',
          muscleGroup: MuscleGroup.quadriceps,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Goblet Squat',
          muscleGroup: MuscleGroup.quadriceps,
          equipment: 'Dumbbells',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 60,
        ),
        ExerciseDefinition(
          name: 'Lunges',
          muscleGroup: MuscleGroup.quadriceps,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Romanian Deadlift',
          muscleGroup: MuscleGroup.hamstrings,
          equipment: 'Dumbbells',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 75,
        ),
        ExerciseDefinition(
          name: 'Leg Curl',
          muscleGroup: MuscleGroup.hamstrings,
          equipment: 'Machine',
          defaultSets: 3,
          defaultReps: 12,
          defaultRestSeconds: 60,
        ),
        ExerciseDefinition(
          name: 'Standing Calf Raise',
          muscleGroup: MuscleGroup.calves,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultReps: 15,
          defaultRestSeconds: 30,
        ),
        ExerciseDefinition(
          name: 'Kettlebell Swing',
          muscleGroup: MuscleGroup.fullBody,
          equipment: 'Kettlebell',
          defaultSets: 3,
          defaultReps: 15,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Burpee',
          muscleGroup: MuscleGroup.fullBody,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultReps: 10,
          defaultRestSeconds: 45,
        ),
        ExerciseDefinition(
          name: 'Mountain Climber',
          muscleGroup: MuscleGroup.fullBody,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultDurationSeconds: 30,
          defaultRestSeconds: 30,
        ),
        ExerciseDefinition(
          name: 'Jumping Jack',
          muscleGroup: MuscleGroup.fullBody,
          equipment: 'Bodyweight',
          defaultSets: 3,
          defaultDurationSeconds: 30,
          defaultRestSeconds: 20,
        ),
        ExerciseDefinition(
          name: 'Deadlift',
          muscleGroup: MuscleGroup.fullBody,
          equipment: 'Barbell',
          defaultSets: 3,
          defaultReps: 5,
          defaultRestSeconds: 120,
        ),
      ];

  static List<ExerciseDefinition> forGroup(MuscleGroup group) =>
      all.where((e) => e.muscleGroup == group).toList(growable: false);

  static ExerciseDefinition? byName(String name) {
    final lower = name.toLowerCase();
    for (final item in all) {
      if (item.name.toLowerCase() == lower) return item;
    }
    return null;
  }
}

class ExerciseDefinition {
  const ExerciseDefinition({
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.defaultSets = 3,
    this.defaultReps,
    this.defaultDurationSeconds,
    this.defaultRestSeconds = 60,
  });

  final String name;
  final MuscleGroup muscleGroup;
  final String equipment;
  final int defaultSets;
  final int? defaultReps;
  final int? defaultDurationSeconds;
  final int defaultRestSeconds;

  WorkoutExercise toExercise({double? weightKg}) {
    return WorkoutExercise(
      id: const Uuid().v4(),
      name: name,
      muscleGroup: muscleGroup,
      equipment: equipment,
      sets: defaultSets,
      reps: defaultReps,
      durationSeconds: defaultDurationSeconds,
      restSeconds: defaultRestSeconds,
      weightKg: weightKg,
    );
  }
}
