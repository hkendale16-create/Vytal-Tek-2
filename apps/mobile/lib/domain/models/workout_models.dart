import 'package:uuid/uuid.dart';

enum WorkoutTimerKind {
  exercise,
  rest,
  interval,
  stopwatch,
  activity,
}

enum WorkoutActivityKind {
  walking,
  running,
  cycling,
  strength,
  cardio,
  hiit,
  custom,
}

extension WorkoutActivityKindX on WorkoutActivityKind {
  String get label => switch (this) {
        WorkoutActivityKind.walking => 'Walking',
        WorkoutActivityKind.running => 'Running',
        WorkoutActivityKind.cycling => 'Cycling',
        WorkoutActivityKind.strength => 'Strength',
        WorkoutActivityKind.cardio => 'Cardio',
        WorkoutActivityKind.hiit => 'HIIT',
        WorkoutActivityKind.custom => 'Custom',
      };

  String get motionHint => switch (this) {
        WorkoutActivityKind.walking => 'walking',
        WorkoutActivityKind.running => 'running',
        WorkoutActivityKind.cycling => 'cycling',
        WorkoutActivityKind.strength => 'strength',
        WorkoutActivityKind.cardio => 'cardio',
        WorkoutActivityKind.hiit => 'hiit',
        WorkoutActivityKind.custom => 'custom',
      };
}

enum WorkoutPlayMode { idle, routine, activity, stopwatch }

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  forearms,
  core,
  glutes,
  quadriceps,
  hamstrings,
  calves,
  fullBody,
}

extension MuscleGroupX on MuscleGroup {
  String get label => switch (this) {
        MuscleGroup.chest => 'Chest',
        MuscleGroup.back => 'Back',
        MuscleGroup.shoulders => 'Shoulders',
        MuscleGroup.biceps => 'Biceps',
        MuscleGroup.triceps => 'Triceps',
        MuscleGroup.forearms => 'Forearms',
        MuscleGroup.core => 'Core',
        MuscleGroup.glutes => 'Glutes',
        MuscleGroup.quadriceps => 'Quadriceps',
        MuscleGroup.hamstrings => 'Hamstrings',
        MuscleGroup.calves => 'Calves',
        MuscleGroup.fullBody => 'Full Body',
      };

  String get aiHint => switch (this) {
        MuscleGroup.chest => 'chest',
        MuscleGroup.back => 'back',
        MuscleGroup.shoulders => 'shoulder',
        MuscleGroup.biceps => 'bicep',
        MuscleGroup.triceps => 'tricep',
        MuscleGroup.forearms => 'forearm',
        MuscleGroup.core => 'core',
        MuscleGroup.glutes => 'glute',
        MuscleGroup.quadriceps => 'quad',
        MuscleGroup.hamstrings => 'hamstring',
        MuscleGroup.calves => 'calf',
        MuscleGroup.fullBody => 'full body',
      };
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.name,
    this.sets = 3,
    this.reps,
    this.durationSeconds,
    this.restSeconds = 60,
    this.weightKg,
    this.notes,
    this.muscleGroup,
    this.equipment,
  });

  final String id;
  final String name;
  final int sets;
  final int? reps;
  final int? durationSeconds;
  final int restSeconds;
  final double? weightKg;
  final String? notes;
  final MuscleGroup? muscleGroup;
  final String? equipment;

  WorkoutExercise copyWith({
    String? name,
    int? sets,
    int? reps,
    int? durationSeconds,
    int? restSeconds,
    double? weightKg,
    String? notes,
    MuscleGroup? muscleGroup,
    String? equipment,
    bool clearWeight = false,
    bool clearReps = false,
    bool clearDuration = false,
  }) {
    return WorkoutExercise(
      id: id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: clearReps ? null : (reps ?? this.reps),
      durationSeconds:
          clearDuration ? null : (durationSeconds ?? this.durationSeconds),
      restSeconds: restSeconds ?? this.restSeconds,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      notes: notes ?? this.notes,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sets': sets,
        'reps': reps,
        'durationSeconds': durationSeconds,
        'restSeconds': restSeconds,
        'weightKg': weightKg,
        'notes': notes,
        'muscleGroup': muscleGroup?.name,
        'equipment': equipment,
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String? ?? 'Exercise',
        sets: json['sets'] as int? ?? 3,
        reps: json['reps'] as int?,
        durationSeconds: json['durationSeconds'] as int?,
        restSeconds: json['restSeconds'] as int? ?? 60,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        muscleGroup: _muscleGroupFrom(json['muscleGroup'] as String?),
        equipment: json['equipment'] as String?,
      );
}

MuscleGroup? _muscleGroupFrom(String? name) {
  if (name == null || name.isEmpty) return null;
  for (final group in MuscleGroup.values) {
    if (group.name == name) return group;
  }
  return null;
}

class WorkoutRoutine {
  const WorkoutRoutine({
    required this.id,
    required this.name,
    required this.exercises,
    this.builtIn = false,
    this.favorite = false,
    this.activityKind = WorkoutActivityKind.strength,
    this.source = 'user',
  });

  final String id;
  final String name;
  final List<WorkoutExercise> exercises;
  final bool builtIn;
  final bool favorite;
  final WorkoutActivityKind activityKind;
  final String source;

  WorkoutRoutine copyWith({
    String? id,
    String? name,
    List<WorkoutExercise>? exercises,
    bool? builtIn,
    bool? favorite,
    WorkoutActivityKind? activityKind,
    String? source,
  }) {
    return WorkoutRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      builtIn: builtIn ?? this.builtIn,
      favorite: favorite ?? this.favorite,
      activityKind: activityKind ?? this.activityKind,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'builtIn': builtIn,
        'favorite': favorite,
        'activityKind': activityKind.name,
        'source': source,
      };

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json) => WorkoutRoutine(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String? ?? 'Routine',
        exercises: ((json['exercises'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(WorkoutExercise.fromJson)
            .toList(),
        builtIn: json['builtIn'] as bool? ?? false,
        favorite: json['favorite'] as bool? ?? false,
        activityKind: WorkoutActivityKind.values.firstWhere(
          (e) => e.name == json['activityKind'],
          orElse: () => WorkoutActivityKind.strength,
        ),
        source: json['source'] as String? ?? 'user',
      );

  static List<WorkoutRoutine> builtIns() {
    const uuid = Uuid();
    return [
      WorkoutRoutine(
        id: 'builtin-full-body',
        name: 'Vytal Full Body',
        builtIn: true,
        activityKind: WorkoutActivityKind.strength,
        source: 'builtin',
        exercises: [
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Bodyweight squat',
            muscleGroup: MuscleGroup.quadriceps,
            equipment: 'Bodyweight',
            sets: 3,
            reps: 12,
            restSeconds: 45,
          ),
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Push-up',
            muscleGroup: MuscleGroup.chest,
            equipment: 'Bodyweight',
            sets: 3,
            reps: 10,
            restSeconds: 45,
          ),
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Plank',
            muscleGroup: MuscleGroup.core,
            equipment: 'Bodyweight',
            sets: 3,
            durationSeconds: 40,
            restSeconds: 30,
          ),
        ],
      ),
      WorkoutRoutine(
        id: 'builtin-intervals',
        name: '30/30 Intervals',
        builtIn: true,
        activityKind: WorkoutActivityKind.hiit,
        source: 'builtin',
        exercises: [
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Work',
            sets: 8,
            durationSeconds: 30,
            restSeconds: 30,
          ),
        ],
      ),
    ];
  }
}

class TimerPhase {
  const TimerPhase({
    required this.kind,
    required this.label,
    required this.seconds,
    this.exerciseId,
    this.exerciseName,
    this.setNumber,
    this.setsTotal,
    this.reps,
    this.weightKg,
    this.muscleGroup,
    this.equipment,
  });

  final WorkoutTimerKind kind;
  final String label;
  final int seconds;
  final String? exerciseId;
  final String? exerciseName;
  final int? setNumber;
  final int? setsTotal;
  final int? reps;
  final double? weightKg;
  final MuscleGroup? muscleGroup;
  final String? equipment;
}

class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({
    required this.id,
    required this.name,
    required this.activityKind,
    required this.durationSeconds,
    required this.completedAt,
    this.calories,
    this.averageHr,
    this.maxHr,
    this.distanceMeters,
    this.notes,
    this.routineId,
    this.playMode = WorkoutPlayMode.activity,
    this.estimatedCalories,
    this.trainingVolumeKg,
  });

  final String id;
  final String name;
  final WorkoutActivityKind activityKind;
  final int durationSeconds;
  final DateTime completedAt;
  final int? calories;
  final int? averageHr;
  final int? maxHr;
  final double? distanceMeters;
  final String? notes;
  final String? routineId;
  final WorkoutPlayMode playMode;
  final int? estimatedCalories;
  final double? trainingVolumeKg;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'activityKind': activityKind.name,
        'durationSeconds': durationSeconds,
        'completedAt': completedAt.toIso8601String(),
        'calories': calories,
        'averageHr': averageHr,
        'maxHr': maxHr,
        'distanceMeters': distanceMeters,
        'notes': notes,
        'routineId': routineId,
        'playMode': playMode.name,
        'estimatedCalories': estimatedCalories,
        'trainingVolumeKg': trainingVolumeKg,
      };

  factory WorkoutHistoryEntry.fromJson(Map<String, dynamic> json) =>
      WorkoutHistoryEntry(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String? ?? 'Workout',
        activityKind: WorkoutActivityKind.values.firstWhere(
          (e) => e.name == json['activityKind'],
          orElse: () => WorkoutActivityKind.custom,
        ),
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        calories: json['calories'] as int?,
        averageHr: json['averageHr'] as int?,
        maxHr: json['maxHr'] as int?,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        routineId: json['routineId'] as String?,
        playMode: WorkoutPlayMode.values.firstWhere(
          (e) => e.name == json['playMode'],
          orElse: () => WorkoutPlayMode.activity,
        ),
        estimatedCalories: json['estimatedCalories'] as int?,
        trainingVolumeKg: (json['trainingVolumeKg'] as num?)?.toDouble(),
      );
}

/// Catalog used by the routine builder — names only, not sensor data.
abstract final class ExerciseCatalog {
  static const names = <String>[
    'Bench Press',
    'Push-up',
    'Incline Dumbbell Press',
    'Barbell Row',
    'Dumbbell Row',
    'Shoulder Press',
    'Bicep Curl',
    'Tricep Dip',
    'Bodyweight squat',
    'Lunges',
    'Glute Bridge',
    'Plank',
    'Deadlift',
    'Kettlebell Swing',
    'Burpee',
    'Mountain Climber',
  ];
}
