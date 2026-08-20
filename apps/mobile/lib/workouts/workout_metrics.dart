import '../domain/models/workout_models.dart';

/// Which HUD tiles a workout type should show. Missing device readings stay blank.
enum WorkoutMetricId {
  elapsed,
  distance,
  pace,
  speed,
  heartRate,
  hrZone,
  calories,
  cadence,
  steps,
  activeMinutes,
  exercise,
  muscleGroup,
  sets,
  reps,
  weight,
  rest,
  volume,
  workInterval,
  restInterval,
  round,
  intervalTimer,
  route,
}

abstract final class WorkoutMetricCatalog {
  static List<WorkoutMetricId> visible({
    required WorkoutActivityKind kind,
    List<WorkoutMetricId>? enabled,
    required bool gpsActive,
    required double distanceMeters,
    int? cadenceRpm,
  }) {
    final ids = List<WorkoutMetricId>.from(enabled ?? forKind(kind));
    if (!ids.contains(WorkoutMetricId.elapsed)) {
      ids.insert(0, WorkoutMetricId.elapsed);
    }
    final gpsOk = gpsActive || distanceMeters > 0;
    if (!gpsOk) {
      ids.removeWhere(needsGps);
    }
    if (cadenceRpm == null) {
      ids.removeWhere((id) => id == WorkoutMetricId.cadence);
    }
    return ids;
  }

  static List<WorkoutMetricId> forKind(WorkoutActivityKind kind) =>
      switch (kind) {
        WorkoutActivityKind.running => const [
            WorkoutMetricId.elapsed,
            WorkoutMetricId.distance,
            WorkoutMetricId.pace,
            WorkoutMetricId.heartRate,
            WorkoutMetricId.hrZone,
            WorkoutMetricId.calories,
            WorkoutMetricId.steps,
            WorkoutMetricId.route,
          ],
        WorkoutActivityKind.walking => const [
            WorkoutMetricId.elapsed,
            WorkoutMetricId.distance,
            WorkoutMetricId.steps,
            WorkoutMetricId.pace,
            WorkoutMetricId.heartRate,
            WorkoutMetricId.calories,
            WorkoutMetricId.activeMinutes,
          ],
        WorkoutActivityKind.cycling => const [
            WorkoutMetricId.elapsed,
            WorkoutMetricId.distance,
            WorkoutMetricId.speed,
            WorkoutMetricId.heartRate,
            WorkoutMetricId.hrZone,
            WorkoutMetricId.calories,
          ],
        WorkoutActivityKind.strength || WorkoutActivityKind.calisthenics =>
          const [
            WorkoutMetricId.exercise,
            WorkoutMetricId.muscleGroup,
            WorkoutMetricId.sets,
            WorkoutMetricId.reps,
            WorkoutMetricId.weight,
            WorkoutMetricId.rest,
            WorkoutMetricId.elapsed,
            WorkoutMetricId.heartRate,
            WorkoutMetricId.volume,
          ],
        WorkoutActivityKind.hiit => const [
            WorkoutMetricId.workInterval,
            WorkoutMetricId.restInterval,
            WorkoutMetricId.round,
            WorkoutMetricId.heartRate,
            WorkoutMetricId.hrZone,
            WorkoutMetricId.elapsed,
            WorkoutMetricId.calories,
            WorkoutMetricId.intervalTimer,
          ],
        WorkoutActivityKind.treadmill ||
        WorkoutActivityKind.stairClimber ||
        WorkoutActivityKind.rowing ||
        WorkoutActivityKind.elliptical ||
        WorkoutActivityKind.jumpRope ||
        WorkoutActivityKind.cardio ||
        WorkoutActivityKind.custom =>
          const [
            WorkoutMetricId.elapsed,
            WorkoutMetricId.heartRate,
            WorkoutMetricId.calories,
            WorkoutMetricId.steps,
          ],
      };

  static const outdoorKinds = {
    WorkoutActivityKind.running,
    WorkoutActivityKind.walking,
    WorkoutActivityKind.cycling,
  };

  static bool usesPhoneGps(WorkoutActivityKind kind) => kind.usesGpsTrack;

  /// Metrics the user can toggle for Cardio / Custom.
  static const configurableIds = <WorkoutMetricId>[
    WorkoutMetricId.heartRate,
    WorkoutMetricId.hrZone,
    WorkoutMetricId.calories,
    WorkoutMetricId.steps,
    WorkoutMetricId.distance,
    WorkoutMetricId.pace,
    WorkoutMetricId.speed,
    WorkoutMetricId.activeMinutes,
  ];

  static String labelFor(WorkoutMetricId id) => switch (id) {
        WorkoutMetricId.elapsed => 'Elapsed',
        WorkoutMetricId.distance => 'Distance',
        WorkoutMetricId.pace => 'Pace',
        WorkoutMetricId.speed => 'Speed',
        WorkoutMetricId.heartRate => 'Heart rate',
        WorkoutMetricId.hrZone => 'HR zone',
        WorkoutMetricId.calories => 'Calories',
        WorkoutMetricId.cadence => 'Cadence',
        WorkoutMetricId.steps => 'Steps',
        WorkoutMetricId.activeMinutes => 'Active minutes',
        WorkoutMetricId.exercise => 'Exercise',
        WorkoutMetricId.muscleGroup => 'Muscle group',
        WorkoutMetricId.sets => 'Sets',
        WorkoutMetricId.reps => 'Reps',
        WorkoutMetricId.weight => 'Weight',
        WorkoutMetricId.rest => 'Rest',
        WorkoutMetricId.volume => 'Volume',
        WorkoutMetricId.workInterval => 'Work interval',
        WorkoutMetricId.restInterval => 'Rest interval',
        WorkoutMetricId.round => 'Round',
        WorkoutMetricId.intervalTimer => 'Interval timer',
        WorkoutMetricId.route => 'Route',
      };

  static bool needsGps(WorkoutMetricId id) =>
      id == WorkoutMetricId.distance ||
      id == WorkoutMetricId.pace ||
      id == WorkoutMetricId.speed ||
      id == WorkoutMetricId.route;

  static double metFor(WorkoutActivityKind kind) => switch (kind) {
        WorkoutActivityKind.running => 9.8,
        WorkoutActivityKind.walking => 3.8,
        WorkoutActivityKind.cycling => 7.5,
        WorkoutActivityKind.treadmill => 8.0,
        WorkoutActivityKind.stairClimber => 9.0,
        WorkoutActivityKind.rowing => 7.0,
        WorkoutActivityKind.elliptical => 5.5,
        WorkoutActivityKind.jumpRope => 11.0,
        WorkoutActivityKind.hiit => 8.5,
        WorkoutActivityKind.strength => 5.0,
        WorkoutActivityKind.calisthenics => 6.0,
        WorkoutActivityKind.cardio => 6.5,
        WorkoutActivityKind.custom => 5.0,
      };

  /// App estimate from elapsed time — never presented as a wearable reading.
  static int estimatedCalories({
    required WorkoutActivityKind kind,
    required int elapsedSeconds,
    double weightKg = 70,
  }) {
    if (elapsedSeconds <= 0) return 0;
    return (metFor(kind) * weightKg * (elapsedSeconds / 3600)).round();
  }

  static String? hrZoneLabel(int? bpm, {int age = 35}) {
    if (bpm == null || bpm <= 0) return null;
    final maxHr = (220 - age).clamp(140, 200);
    final pct = bpm / maxHr;
    if (pct < 0.6) return 'Zone 1 · Easy';
    if (pct < 0.7) return 'Zone 2 · Endurance';
    if (pct < 0.8) return 'Zone 3 · Tempo';
    if (pct < 0.9) return 'Zone 4 · Threshold';
    return 'Zone 5 · Peak';
  }

  static double kgToLb(double kg) => kg * 2.2046226218;

  static double lbToKg(double lb) => lb / 2.2046226218;
}
