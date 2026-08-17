import 'package:uuid/uuid.dart';

enum WorkoutTimerKind {
  exercise,
  rest,
  interval,
  stopwatch,
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.name,
    this.sets = 3,
    this.reps,
    this.durationSeconds,
    this.restSeconds = 60,
    this.notes,
  });

  final String id;
  final String name;
  final int sets;
  final int? reps;
  final int? durationSeconds;
  final int restSeconds;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sets': sets,
        'reps': reps,
        'durationSeconds': durationSeconds,
        'restSeconds': restSeconds,
        'notes': notes,
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String? ?? 'Exercise',
        sets: json['sets'] as int? ?? 3,
        reps: json['reps'] as int?,
        durationSeconds: json['durationSeconds'] as int?,
        restSeconds: json['restSeconds'] as int? ?? 60,
        notes: json['notes'] as String?,
      );
}

class WorkoutRoutine {
  const WorkoutRoutine({
    required this.id,
    required this.name,
    required this.exercises,
    this.builtIn = false,
    this.favorite = false,
  });

  final String id;
  final String name;
  final List<WorkoutExercise> exercises;
  final bool builtIn;
  final bool favorite;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'builtIn': builtIn,
        'favorite': favorite,
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
      );

  static List<WorkoutRoutine> builtIns() {
    const uuid = Uuid();
    return [
      WorkoutRoutine(
        id: 'builtin-full-body',
        name: 'Vytal Full Body',
        builtIn: true,
        exercises: [
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Bodyweight squat',
            sets: 3,
            reps: 12,
            restSeconds: 45,
          ),
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Push-up',
            sets: 3,
            reps: 10,
            restSeconds: 45,
          ),
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Plank',
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
  });

  final WorkoutTimerKind kind;
  final String label;
  final int seconds;
}
