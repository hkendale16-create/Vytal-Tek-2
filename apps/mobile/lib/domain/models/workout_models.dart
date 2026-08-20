import 'package:uuid/uuid.dart';

enum WorkoutTimerKind {
  exercise,
  rest,
  interval,
  stopwatch,
  activity,
}

enum WorkoutHubCategory { cardio, strength, calisthenics }

enum WorkoutActivityKind {
  walking,
  running,
  cycling,
  treadmill,
  stairClimber,
  rowing,
  elliptical,
  jumpRope,
  strength,
  calisthenics,
  cardio,
  hiit,
  custom;

  static WorkoutActivityKind fromJson(
    String? raw, {
    WorkoutActivityKind orElse = WorkoutActivityKind.custom,
  }) {
    if (raw == null || raw.isEmpty) return orElse;
    return WorkoutActivityKind.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => orElse,
    );
  }
}

extension WorkoutActivityKindX on WorkoutActivityKind {
  String get label => switch (this) {
        WorkoutActivityKind.walking => 'Walking',
        WorkoutActivityKind.running => 'Running',
        WorkoutActivityKind.cycling => 'Cycling',
        WorkoutActivityKind.treadmill => 'Treadmill',
        WorkoutActivityKind.stairClimber => 'Stair climber',
        WorkoutActivityKind.rowing => 'Rowing',
        WorkoutActivityKind.elliptical => 'Elliptical',
        WorkoutActivityKind.jumpRope => 'Jump rope',
        WorkoutActivityKind.strength => 'Strength',
        WorkoutActivityKind.calisthenics => 'Calisthenics',
        WorkoutActivityKind.cardio => 'Custom cardio',
        WorkoutActivityKind.hiit => 'HIIT',
        WorkoutActivityKind.custom => 'Custom',
      };

  String get motionHint => switch (this) {
        WorkoutActivityKind.walking => 'walking',
        WorkoutActivityKind.running => 'running',
        WorkoutActivityKind.cycling => 'cycling',
        WorkoutActivityKind.treadmill => 'treadmill',
        WorkoutActivityKind.stairClimber => 'stairs',
        WorkoutActivityKind.rowing => 'rowing',
        WorkoutActivityKind.elliptical => 'elliptical',
        WorkoutActivityKind.jumpRope => 'jump rope',
        WorkoutActivityKind.strength => 'strength',
        WorkoutActivityKind.calisthenics => 'calisthenics',
        WorkoutActivityKind.cardio => 'cardio',
        WorkoutActivityKind.hiit => 'hiit',
        WorkoutActivityKind.custom => 'custom',
      };

  String get hubHint => switch (this) {
        WorkoutActivityKind.running => 'Time, pace, HR zone, outdoor GPS',
        WorkoutActivityKind.walking => 'Steps, pace, active minutes',
        WorkoutActivityKind.cycling => 'Speed and HR zones',
        WorkoutActivityKind.treadmill => 'Indoor run metrics, no GPS track',
        WorkoutActivityKind.stairClimber => 'Elapsed, HR, estimated calories',
        WorkoutActivityKind.rowing => 'Stroke-paced cardio, no invented cadence',
        WorkoutActivityKind.elliptical => 'Low-impact indoor cardio',
        WorkoutActivityKind.jumpRope => 'Elapsed, HR, estimated calories',
        WorkoutActivityKind.strength => 'Sets, reps, muscle groups, rest',
        WorkoutActivityKind.calisthenics => 'Bodyweight sets with adaptive fields',
        WorkoutActivityKind.cardio => 'Choose which metrics to show',
        WorkoutActivityKind.hiit => 'Work / rest intervals and rounds',
        WorkoutActivityKind.custom => 'Build your own metric mix',
      };

  WorkoutHubCategory get hubCategory => switch (this) {
        WorkoutActivityKind.strength || WorkoutActivityKind.custom =>
          WorkoutHubCategory.strength,
        WorkoutActivityKind.calisthenics => WorkoutHubCategory.calisthenics,
        WorkoutActivityKind.walking ||
        WorkoutActivityKind.running ||
        WorkoutActivityKind.cycling ||
        WorkoutActivityKind.treadmill ||
        WorkoutActivityKind.stairClimber ||
        WorkoutActivityKind.rowing ||
        WorkoutActivityKind.elliptical ||
        WorkoutActivityKind.jumpRope ||
        WorkoutActivityKind.cardio ||
        WorkoutActivityKind.hiit =>
          WorkoutHubCategory.cardio,
      };

  bool get usesGpsTrack =>
      this == WorkoutActivityKind.running ||
      this == WorkoutActivityKind.walking ||
      this == WorkoutActivityKind.cycling;

  bool get usesMuscleGroups =>
      this == WorkoutActivityKind.strength ||
      this == WorkoutActivityKind.calisthenics ||
      this == WorkoutActivityKind.custom;

  bool get usesStrengthSets =>
      this == WorkoutActivityKind.strength ||
      this == WorkoutActivityKind.calisthenics;

  /// Kinds shown in the routine builder dropdown — not every cardio machine.
  static const builderKinds = <WorkoutActivityKind>[
    WorkoutActivityKind.strength,
    WorkoutActivityKind.calisthenics,
    WorkoutActivityKind.cardio,
    WorkoutActivityKind.hiit,
    WorkoutActivityKind.custom,
  ];

  static const cardioKinds = <WorkoutActivityKind>[
    WorkoutActivityKind.running,
    WorkoutActivityKind.walking,
    WorkoutActivityKind.cycling,
    WorkoutActivityKind.treadmill,
    WorkoutActivityKind.stairClimber,
    WorkoutActivityKind.rowing,
    WorkoutActivityKind.elliptical,
    WorkoutActivityKind.jumpRope,
    WorkoutActivityKind.cardio,
    WorkoutActivityKind.hiit,
  ];
}

enum WorkoutPlayMode { idle, routine, activity, stopwatch }

enum WorkoutSetType {
  working,
  warmup,
  drop,
  failure;

  static WorkoutSetType fromJson(String? raw) {
    return WorkoutSetType.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => WorkoutSetType.working,
    );
  }
}

extension WorkoutSetTypeX on WorkoutSetType {
  String get shortLabel => switch (this) {
        WorkoutSetType.working => 'W',
        WorkoutSetType.warmup => 'WU',
        WorkoutSetType.drop => 'D',
        WorkoutSetType.failure => 'F',
      };

  String get label => switch (this) {
        WorkoutSetType.working => 'Working',
        WorkoutSetType.warmup => 'Warm-up',
        WorkoutSetType.drop => 'Drop',
        WorkoutSetType.failure => 'Failure',
      };

  WorkoutSetType get next => switch (this) {
        WorkoutSetType.working => WorkoutSetType.warmup,
        WorkoutSetType.warmup => WorkoutSetType.drop,
        WorkoutSetType.drop => WorkoutSetType.failure,
        WorkoutSetType.failure => WorkoutSetType.working,
      };

  bool get countsForVolume => this != WorkoutSetType.warmup;
}

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
    this.notes,
  });

  final String id;
  final String name;
  final List<WorkoutExercise> exercises;
  final bool builtIn;
  final bool favorite;
  final WorkoutActivityKind activityKind;
  final String source;
  final String? notes;

  WorkoutRoutine copyWith({
    String? id,
    String? name,
    List<WorkoutExercise>? exercises,
    bool? builtIn,
    bool? favorite,
    WorkoutActivityKind? activityKind,
    String? source,
    String? notes,
  }) {
    return WorkoutRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      builtIn: builtIn ?? this.builtIn,
      favorite: favorite ?? this.favorite,
      activityKind: activityKind ?? this.activityKind,
      source: source ?? this.source,
      notes: notes ?? this.notes,
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
        'notes': notes,
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
        activityKind: WorkoutActivityKind.fromJson(
          json['activityKind'] as String?,
          orElse: WorkoutActivityKind.strength,
        ),
        source: json['source'] as String? ?? 'user',
        notes: json['notes'] as String?,
      );

  String get sourceLabel => switch (source) {
        'ai' => 'Ask Vytal',
        'builtin' => 'Library',
        'user' || 'custom' => 'Yours',
        _ => 'Activity',
      };

  List<String> get muscleGroupSummary {
    final groups = <String>{};
    for (final exercise in exercises) {
      final group = exercise.muscleGroup;
      if (group != null) groups.add(group.label);
    }
    final ordered = groups.toList()..sort();
    return ordered;
  }

  int get estimatedMinutes {
    if (exercises.isEmpty) return 0;
    var seconds = 0;
    for (final exercise in exercises) {
      final work = exercise.durationSeconds ?? ((exercise.reps ?? 10) * 3);
      seconds += exercise.sets * (work + exercise.restSeconds);
    }
    if (seconds <= 0) return 0;
    final minutes = (seconds / 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }

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
    this.setType = WorkoutSetType.working,
    this.completed = false,
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
  final WorkoutSetType setType;
  final bool completed;

  bool get isTimedHold =>
      kind == WorkoutTimerKind.exercise && reps == null && seconds > 0;

  TimerPhase copyWith({
    WorkoutTimerKind? kind,
    String? label,
    int? seconds,
    String? exerciseId,
    String? exerciseName,
    int? setNumber,
    int? setsTotal,
    int? reps,
    double? weightKg,
    MuscleGroup? muscleGroup,
    String? equipment,
    WorkoutSetType? setType,
    bool? completed,
    bool clearReps = false,
    bool clearWeight = false,
  }) {
    return TimerPhase(
      kind: kind ?? this.kind,
      label: label ?? this.label,
      seconds: seconds ?? this.seconds,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      setNumber: setNumber ?? this.setNumber,
      setsTotal: setsTotal ?? this.setsTotal,
      reps: clearReps ? null : (reps ?? this.reps),
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      setType: setType ?? this.setType,
      completed: completed ?? this.completed,
    );
  }
}

class WorkoutSetLog {
  const WorkoutSetLog({
    required this.exerciseName,
    required this.setNumber,
    required this.setType,
    required this.completed,
    this.reps,
    this.weightKg,
    this.durationSeconds,
  });

  final String exerciseName;
  final int setNumber;
  final WorkoutSetType setType;
  final bool completed;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'setNumber': setNumber,
        'setType': setType.name,
        'completed': completed,
        'reps': reps,
        'weightKg': weightKg,
        'durationSeconds': durationSeconds,
      };

  factory WorkoutSetLog.fromJson(Map<String, dynamic> json) => WorkoutSetLog(
        exerciseName: json['exerciseName'] as String? ?? 'Set',
        setNumber: json['setNumber'] as int? ?? 0,
        setType: WorkoutSetType.fromJson(json['setType'] as String?),
        completed: json['completed'] as bool? ?? false,
        reps: json['reps'] as int?,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        durationSeconds: json['durationSeconds'] as int?,
      );

  String get summary {
    final type = setType == WorkoutSetType.working ? '' : '${setType.shortLabel} ';
    if (durationSeconds != null && reps == null) {
      return '$type#$setNumber · ${durationSeconds}s';
    }
    if (weightKg != null && reps != null) {
      return '$type#$setNumber · ${weightKg!.round()}kg × $reps';
    }
    if (reps != null) return '$type#$setNumber · $reps reps';
    return '$type#$setNumber';
  }
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
    this.setLogs = const [],
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
  final List<WorkoutSetLog> setLogs;

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
        'setLogs': setLogs.map((e) => e.toJson()).toList(),
      };

  factory WorkoutHistoryEntry.fromJson(Map<String, dynamic> json) =>
      WorkoutHistoryEntry(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String? ?? 'Workout',
        activityKind: WorkoutActivityKind.fromJson(
          json['activityKind'] as String?,
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
        setLogs: ((json['setLogs'] as List?) ?? const [])
            .cast<Map>()
            .map((e) => WorkoutSetLog.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
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
