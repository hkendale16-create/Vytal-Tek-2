import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../devices/connection/device_connection_controller.dart';
import '../domain/devices/device_connection_state.dart';
import '../domain/models/entitlements.dart';
import '../domain/models/workout_models.dart';
import '../monitoring/monitoring_controller.dart';
import '../state/app_session_controller.dart';
import 'workout_gps.dart';
import 'workout_metrics.dart';

const _routinesKey = 'vytal.workouts.routines.v1';
const _historyKey = 'vytal.workouts.history.v1';

class WorkoutLibraryState {
  const WorkoutLibraryState({required this.routines});

  final List<WorkoutRoutine> routines;

  List<WorkoutRoutine> get builtIn =>
      routines.where((r) => r.builtIn).toList(growable: false);

  List<WorkoutRoutine> get custom =>
      routines.where((r) => !r.builtIn).toList(growable: false);

  List<WorkoutRoutine> get recentlyUsed =>
      custom.isNotEmpty ? custom.take(3).toList() : builtIn.take(2).toList();
}

final workoutLibraryProvider =
    StateNotifierProvider<WorkoutLibraryController, WorkoutLibraryState>((ref) {
  return WorkoutLibraryController(ref)..restore();
});

class WorkoutLibraryController extends StateNotifier<WorkoutLibraryState> {
  WorkoutLibraryController(this._ref)
      : super(WorkoutLibraryState(routines: WorkoutRoutine.builtIns()));

  final Ref _ref;
  final _uuid = const Uuid();

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_routinesKey);
    final custom = <WorkoutRoutine>[];
    if (raw != null) {
      try {
        custom.addAll(
          (jsonDecode(raw) as List)
              .cast<Map<String, dynamic>>()
              .map(WorkoutRoutine.fromJson)
              .where((r) => !r.builtIn),
        );
      } catch (_) {
        // Keep built-ins only.
      }
    }
    state = WorkoutLibraryState(
      routines: [...WorkoutRoutine.builtIns(), ...custom],
    );
  }

  Future<void> addCustom({
    required String name,
    required List<WorkoutExercise> exercises,
    WorkoutActivityKind activityKind = WorkoutActivityKind.strength,
    String source = 'user',
  }) async {
    final session = _ref.read(appSessionProvider);
    if (!session.entitlements.canUse(EntitlementKeys.workoutsCustom)) {
      return;
    }
    final routine = WorkoutRoutine(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Custom routine' : name.trim(),
      exercises: exercises,
      activityKind: activityKind,
      source: source,
    );
    await addCustomRoutine(routine);
  }

  Future<WorkoutRoutine?> addCustomRoutine(WorkoutRoutine routine) async {
    final session = _ref.read(appSessionProvider);
    if (!session.entitlements.canUse(EntitlementKeys.workoutsCustom)) {
      return null;
    }
    final saved = routine.copyWith(
      id: routine.id.isEmpty ? _uuid.v4() : routine.id,
      builtIn: false,
    );
    state = WorkoutLibraryState(routines: [...state.routines, saved]);
    await _persistCustom();
    return saved;
  }

  Future<void> updateCustom(WorkoutRoutine routine) async {
    if (routine.builtIn) return;
    state = WorkoutLibraryState(
      routines: state.routines
          .map((r) => r.id == routine.id ? routine : r)
          .toList(growable: false),
    );
    await _persistCustom();
  }

  Future<void> deleteCustom(String id) async {
    state = WorkoutLibraryState(
      routines: state.routines
          .where((r) => r.id != id || r.builtIn)
          .toList(growable: false),
    );
    await _persistCustom();
  }

  Future<void> _persistCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = state.custom.map((r) => r.toJson()).toList();
    await prefs.setString(_routinesKey, jsonEncode(custom));
  }
}

class WorkoutHistoryState {
  const WorkoutHistoryState({required this.entries});

  final List<WorkoutHistoryEntry> entries;
}

final workoutHistoryProvider =
    StateNotifierProvider<WorkoutHistoryController, WorkoutHistoryState>((ref) {
  return WorkoutHistoryController()..restore();
});

class WorkoutHistoryController extends StateNotifier<WorkoutHistoryState> {
  WorkoutHistoryController() : super(const WorkoutHistoryState(entries: []));

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return;
    try {
      final entries = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(WorkoutHistoryEntry.fromJson)
          .toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
      state = WorkoutHistoryState(entries: entries);
    } catch (_) {
      state = const WorkoutHistoryState(entries: []);
    }
  }

  Future<void> add(WorkoutHistoryEntry entry) async {
    state = WorkoutHistoryState(entries: [entry, ...state.entries]);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(state.entries.map((e) => e.toJson()).toList()),
    );
  }
}

class WorkoutSessionState {
  const WorkoutSessionState({
    required this.routine,
    required this.phases,
    required this.phaseIndex,
    required this.remainingSeconds,
    required this.running,
    required this.completed,
    this.stopwatchElapsed = 0,
    this.playMode = WorkoutPlayMode.idle,
    this.activityKind,
    this.runningSince,
    this.elapsedAtResumeSeconds = 0,
    this.notes = '',
    this.summaryPending = false,
    this.hrSamples = const [],
    this.hiitWorkSeconds = 40,
    this.hiitRestSeconds = 20,
    this.hiitRounds = 8,
    this.baselineSteps,
    this.enabledMetrics,
    this.distanceMeters = 0,
    this.currentSpeedMps,
    this.gpsActive = false,
    this.gpsDenied = false,
    this.cadenceRpm,
    this.sessionSteps,
    this.routePoints = const [],
  });

  final WorkoutRoutine? routine;
  final List<TimerPhase> phases;
  final int phaseIndex;
  final int remainingSeconds;
  final bool running;
  final bool completed;
  final int stopwatchElapsed;
  final WorkoutPlayMode playMode;
  final WorkoutActivityKind? activityKind;
  final DateTime? runningSince;
  final int elapsedAtResumeSeconds;
  final String notes;
  final bool summaryPending;
  final List<int> hrSamples;
  final int hiitWorkSeconds;
  final int hiitRestSeconds;
  final int hiitRounds;
  final int? baselineSteps;
  final List<WorkoutMetricId>? enabledMetrics;
  final double distanceMeters;
  final double? currentSpeedMps;
  final bool gpsActive;
  final bool gpsDenied;
  final int? cadenceRpm;
  final int? sessionSteps;
  final List<({double x, double y})> routePoints;

  bool get hasProgress =>
      elapsedSeconds() > 0 ||
      phaseIndex > 0 ||
      hrSamples.isNotEmpty ||
      distanceMeters > 0 ||
      completed;

  List<WorkoutMetricId> get visibleMetrics {
    final kind = activityKind ?? WorkoutActivityKind.custom;
    return WorkoutMetricCatalog.visible(
      kind: kind,
      enabled: enabledMetrics,
      gpsActive: gpsActive || distanceMeters > 0,
      distanceMeters: distanceMeters,
      cadenceRpm: cadenceRpm,
    );
  }

  TimerPhase? get currentPhase =>
      phases.isEmpty || phaseIndex >= phases.length ? null : phases[phaseIndex];

  TimerPhase? get previousPhase =>
      phaseIndex > 0 && phaseIndex - 1 < phases.length
          ? phases[phaseIndex - 1]
          : null;

  TimerPhase? get nextPhase =>
      phaseIndex + 1 < phases.length ? phases[phaseIndex + 1] : null;

  int elapsedSeconds([DateTime? now]) {
    return elapsedAtResumeSeconds < 0 ? 0 : elapsedAtResumeSeconds;
  }

  int remainingNow([DateTime? now]) => remainingSeconds;

  int? get averageHr {
    if (hrSamples.isEmpty) return null;
    return (hrSamples.reduce((a, b) => a + b) / hrSamples.length).round();
  }

  int? get maxHr => hrSamples.isEmpty ? null : hrSamples.reduce(mathMax);

  static int mathMax(int a, int b) => a > b ? a : b;

  static const idle = WorkoutSessionState(
    routine: null,
    phases: [],
    phaseIndex: 0,
    remainingSeconds: 0,
    running: false,
    completed: false,
  );
}

final pendingRoutineDraftProvider =
    StateProvider<WorkoutRoutine?>((ref) => null);

final workoutSessionProvider =
    StateNotifierProvider<WorkoutSessionController, WorkoutSessionState>((ref) {
  return WorkoutSessionController(ref);
});

/// Exercise / rest / interval / activity / stopwatch engine.
class WorkoutSessionController extends StateNotifier<WorkoutSessionState> {
  WorkoutSessionController(this._ref) : super(WorkoutSessionState.idle);

  final Ref _ref;
  Timer? _tick;
  Timer? _hrPoll;
  StreamSubscription<int>? _liveHrSub;
  StreamSubscription<GpsFix>? _gpsSub;
  final _gps = WorkoutGpsTracker();

  void startRoutine(WorkoutRoutine routine) {
    _resetSensors();
    final phases = buildPhases(routine);
    _tick?.cancel();
    state = WorkoutSessionState(
      routine: routine,
      phases: phases,
      phaseIndex: 0,
      remainingSeconds: phases.isEmpty ? 0 : phases.first.seconds,
      running: true,
      completed: phases.isEmpty,
      playMode: WorkoutPlayMode.routine,
      activityKind: routine.activityKind,
      runningSince: DateTime.now(),
    );
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(true);
    _arm();
    unawaited(_setDeviceWorkoutMonitoring(true));
  }

  void startActivity(
    WorkoutActivityKind kind, {
    String? name,
    int initialElapsedSeconds = 0,
    int hiitWorkSeconds = 40,
    int hiitRestSeconds = 20,
    int hiitRounds = 8,
    List<WorkoutMetricId>? enabledMetrics,
    int? baselineSteps,
    bool gpsDenied = false,
  }) {
    _tick?.cancel();
    final label = name ?? kind.label;
    if (kind == WorkoutActivityKind.hiit) {
      startHiit(
        name: label,
        workSeconds: hiitWorkSeconds,
        restSeconds: hiitRestSeconds,
        rounds: hiitRounds,
      );
      return;
    }
    if (kind == WorkoutActivityKind.strength) {
      startStrengthDraft(name: label);
      return;
    }
    _resetSensors();
    state = WorkoutSessionState(
      routine: WorkoutRoutine(
        id: 'activity-${kind.name}',
        name: label,
        exercises: const [],
        activityKind: kind,
        source: 'activity',
      ),
      phases: [
        TimerPhase(
          kind: WorkoutTimerKind.activity,
          label: label,
          seconds: 0,
        ),
      ],
      phaseIndex: 0,
      remainingSeconds: 0,
      running: true,
      completed: false,
      playMode: WorkoutPlayMode.activity,
      activityKind: kind,
      runningSince: DateTime.now(),
      elapsedAtResumeSeconds: initialElapsedSeconds,
      enabledMetrics: enabledMetrics,
      baselineSteps: baselineSteps,
      gpsDenied: gpsDenied,
    );
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(true);
    _arm();
    unawaited(_setDeviceWorkoutMonitoring(true));
  }

  void startHiit({
    String name = 'HIIT',
    int workSeconds = 40,
    int restSeconds = 20,
    int rounds = 8,
  }) {
    _resetSensors();
    final phases = <TimerPhase>[];
    for (var round = 1; round <= rounds; round++) {
      phases.add(
        TimerPhase(
          kind: WorkoutTimerKind.interval,
          label: 'Work · round $round/$rounds',
          seconds: workSeconds,
          setNumber: round,
          setsTotal: rounds,
        ),
      );
      if (round < rounds) {
        phases.add(
          TimerPhase(
            kind: WorkoutTimerKind.rest,
            label: 'Rest · round $round/$rounds',
            seconds: restSeconds,
            setNumber: round,
            setsTotal: rounds,
          ),
        );
      }
    }
    state = WorkoutSessionState(
      routine: WorkoutRoutine(
        id: 'activity-hiit',
        name: name,
        exercises: const [],
        activityKind: WorkoutActivityKind.hiit,
        source: 'activity',
      ),
      phases: phases,
      phaseIndex: 0,
      remainingSeconds: phases.first.seconds,
      running: true,
      completed: false,
      playMode: WorkoutPlayMode.routine,
      activityKind: WorkoutActivityKind.hiit,
      runningSince: DateTime.now(),
      hiitWorkSeconds: workSeconds,
      hiitRestSeconds: restSeconds,
      hiitRounds: rounds,
    );
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(true);
    _arm();
    unawaited(_setDeviceWorkoutMonitoring(true));
  }

  void startStrengthDraft({String name = 'Strength'}) {
    _resetSensors();
    state = WorkoutSessionState(
      routine: WorkoutRoutine(
        id: 'activity-strength',
        name: name,
        exercises: const [],
        activityKind: WorkoutActivityKind.strength,
        source: 'activity',
      ),
      phases: const [],
      phaseIndex: 0,
      remainingSeconds: 0,
      running: true,
      completed: false,
      playMode: WorkoutPlayMode.routine,
      activityKind: WorkoutActivityKind.strength,
      runningSince: DateTime.now(),
    );
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(true);
    _arm();
    unawaited(_setDeviceWorkoutMonitoring(true));
  }

  void addExerciseToSession(WorkoutExercise exercise) {
    final current = state.routine ??
        WorkoutRoutine(
          id: 'activity-strength',
          name: 'Strength',
          exercises: const [],
          activityKind: WorkoutActivityKind.strength,
          source: 'activity',
        );
    final routine = current.copyWith(
      exercises: [...current.exercises, exercise],
    );
    final phases = buildPhases(routine);
    final wasEmpty = state.phases.isEmpty;
    final nextIndex = wasEmpty
        ? 0
        : state.phaseIndex.clamp(0, phases.isEmpty ? 0 : phases.length - 1);
    state = _copy(
      routine: routine,
      phases: phases,
      phaseIndex: nextIndex,
      remainingSeconds: phases.isEmpty ? 0 : phases[nextIndex].seconds,
      running: true,
      completed: false,
      runningSince: DateTime.now(),
    );
    _arm();
  }

  void addSetToCurrentExercise() {
    final routine = state.routine;
    final phase = state.currentPhase;
    if (routine == null || phase?.exerciseId == null) return;
    final id = phase!.exerciseId!;
    final exercises = [
      for (final ex in routine.exercises)
        if (ex.id == id) ex.copyWith(sets: ex.sets + 1) else ex,
    ];
    final updatedEx = exercises.firstWhere((e) => e.id == id);
    final newSet = updatedEx.sets;
    final phases = [
      for (final p in state.phases)
        if (p.exerciseId == id)
          p.copyWith(
            setsTotal: newSet,
            label: p.kind == WorkoutTimerKind.exercise && p.setNumber != null
                ? '${p.exerciseName} · set ${p.setNumber}/$newSet'
                : p.label,
          )
        else
          p,
    ];
    var lastIndex = phases.lastIndexWhere((p) => p.exerciseId == id);
    if (lastIndex < 0) lastIndex = phases.length - 1;
    final workSeconds =
        updatedEx.durationSeconds ?? ((updatedEx.reps ?? 10) * 3);
    final insert = <TimerPhase>[
      TimerPhase(
        kind: WorkoutTimerKind.exercise,
        label: '${updatedEx.name} · set $newSet/$newSet',
        seconds: workSeconds.clamp(5, 600),
        exerciseId: id,
        exerciseName: updatedEx.name,
        setNumber: newSet,
        setsTotal: newSet,
        reps: updatedEx.reps,
        weightKg: updatedEx.weightKg,
        muscleGroup: updatedEx.muscleGroup,
        equipment: updatedEx.equipment,
      ),
    ];
    if (updatedEx.restSeconds > 0) {
      insert.add(
        TimerPhase(
          kind: WorkoutTimerKind.rest,
          label: 'Rest',
          seconds: updatedEx.restSeconds,
          exerciseId: id,
          exerciseName: updatedEx.name,
          setNumber: newSet,
          setsTotal: newSet,
          muscleGroup: updatedEx.muscleGroup,
          equipment: updatedEx.equipment,
        ),
      );
    }
    phases.insertAll(lastIndex + 1, insert);
    state = _copy(
      routine: routine.copyWith(exercises: exercises),
      phases: phases,
      phaseIndex: state.phaseIndex.clamp(0, phases.length - 1),
    );
  }

  void updateCurrentSet({int? reps, double? weightKg, int? restSeconds}) {
    if (state.phases.isEmpty) return;
    final i = state.phaseIndex.clamp(0, state.phases.length - 1);
    final phase = state.phases[i];
    final phases = [...state.phases];
    phases[i] = phase.copyWith(
      reps: reps,
      weightKg: weightKg,
      clearReps: reps != null && reps <= 0,
      clearWeight: weightKg != null && weightKg <= 0,
    );
    if (restSeconds != null) {
      for (var j = i + 1; j < phases.length; j++) {
        if (phases[j].kind == WorkoutTimerKind.rest &&
            phases[j].exerciseId == phase.exerciseId) {
          phases[j] = phases[j].copyWith(seconds: restSeconds);
          break;
        }
      }
    }
    var routine = state.routine;
    if (routine != null && phase.exerciseId != null) {
      routine = routine.copyWith(
        exercises: [
          for (final ex in routine.exercises)
            if (ex.id == phase.exerciseId)
              ex.copyWith(
                reps: reps,
                weightKg: weightKg,
                restSeconds: restSeconds,
                clearReps: reps != null && reps <= 0,
                clearWeight: weightKg != null && weightKg <= 0,
              )
            else
              ex,
        ],
      );
    }
    state = _copy(
      routine: routine,
      phases: phases,
    );
  }

  /// Expand a routine into ordered exercise / rest phases (min 5s work).
  static List<TimerPhase> buildPhases(WorkoutRoutine routine) {
    final phases = <TimerPhase>[];
    for (var e = 0; e < routine.exercises.length; e++) {
      final exercise = routine.exercises[e];
      for (var set = 1; set <= exercise.sets; set++) {
        final workSeconds = exercise.durationSeconds ??
            ((exercise.reps ?? 10) * 3); // coarse paced reps
        phases.add(
          TimerPhase(
            kind: WorkoutTimerKind.exercise,
            label: '${exercise.name} · set $set/${exercise.sets}',
            seconds: workSeconds.clamp(5, 600),
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            setNumber: set,
            setsTotal: exercise.sets,
            reps: exercise.reps,
            weightKg: exercise.weightKg,
            muscleGroup: exercise.muscleGroup,
            equipment: exercise.equipment,
          ),
        );
        final isLastSetOfExercise = set == exercise.sets;
        final isLastExercise = e == routine.exercises.length - 1;
        if (exercise.restSeconds > 0 &&
            (!isLastSetOfExercise || !isLastExercise)) {
          phases.add(
            TimerPhase(
              kind: WorkoutTimerKind.rest,
              label: 'Rest',
              seconds: exercise.restSeconds,
              exerciseId: exercise.id,
              exerciseName: exercise.name,
              setNumber: set,
              setsTotal: exercise.sets,
              muscleGroup: exercise.muscleGroup,
              equipment: exercise.equipment,
            ),
          );
        }
      }
    }
    return phases;
  }

  void startStopwatch() {
    _tick?.cancel();
    state = WorkoutSessionState(
      routine: null,
      phases: const [
        TimerPhase(
          kind: WorkoutTimerKind.stopwatch,
          label: 'Stopwatch',
          seconds: 0,
        ),
      ],
      phaseIndex: 0,
      remainingSeconds: 0,
      running: true,
      completed: false,
      playMode: WorkoutPlayMode.stopwatch,
      runningSince: DateTime.now(),
    );
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(true);
    _arm();
  }

  void pause() {
    _tick?.cancel();
    _hrPoll?.cancel();
    state = _copy(
      running: false,
      clearRunningSince: true,
    );
  }

  void resume() {
    if (state.completed) return;
    if (state.phases.isEmpty &&
        state.playMode != WorkoutPlayMode.routine) {
      return;
    }
    state = _copy(
      running: true,
      remainingSeconds: state.remainingSeconds,
      elapsedAtResumeSeconds: state.elapsedAtResumeSeconds,
      runningSince: DateTime.now(),
    );
    _arm();
  }

  void completeSet() {
    if (state.playMode != WorkoutPlayMode.routine) return;
    if (state.completed || state.phases.isEmpty) return;
    _goToPhase(state.phaseIndex + 1);
  }

  void skip() {
    if (state.phases.isEmpty || state.completed) return;
    _goToPhase(state.phaseIndex + 1);
  }

  void previousStep() {
    if (state.phaseIndex <= 0) return;
    _goToPhase(state.phaseIndex - 1);
  }

  void resetSession() {
    final kind = state.activityKind;
    final routine = state.routine;
    final mode = state.playMode;
    final work = state.hiitWorkSeconds;
    final rest = state.hiitRestSeconds;
    final rounds = state.hiitRounds;
    stop();
    if (mode == WorkoutPlayMode.routine &&
        routine != null &&
        routine.source != 'activity') {
      startRoutine(routine);
      pause();
      return;
    }
    if (kind == WorkoutActivityKind.hiit) {
      startHiit(workSeconds: work, restSeconds: rest, rounds: rounds);
      pause();
      return;
    }
    if (kind != null) {
      startActivity(kind);
      pause();
    }
  }

  void stopAndSummarize() => finish();

  void finish() {
    _tick?.cancel();
    _hrPoll?.cancel();
    unawaited(_setDeviceWorkoutMonitoring(false));
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(false);
    state = _copy(
      running: false,
      completed: true,
      summaryPending: true,
      remainingSeconds: 0,
      elapsedAtResumeSeconds: state.elapsedSeconds(),
      stopwatchElapsed: state.elapsedSeconds(),
      clearRunningSince: true,
    );
  }

  void setNotes(String notes) {
    state = _copy(notes: notes);
  }

  void recordHeartRate(int? bpm) {
    if (bpm == null || bpm <= 0) return;
    final next = [...state.hrSamples, bpm];
    if (next.length > 400) {
      next.removeRange(0, next.length - 400);
    }
    state = _copy(hrSamples: next);
  }

  Future<void> saveToHistory() async {
    final duration = state.elapsedSeconds();
    final kind = state.activityKind ?? WorkoutActivityKind.custom;
    final weight = _ref.read(appSessionProvider).profile.weightKg ?? 70;
    final estimated = WorkoutMetricCatalog.estimatedCalories(
      kind: kind,
      elapsedSeconds: duration,
      weightKg: weight,
    );
    final volume = _trainingVolumeKg();
    final entry = WorkoutHistoryEntry(
      id: const Uuid().v4(),
      name: state.routine?.name ?? kind.label,
      activityKind: kind,
      durationSeconds: duration,
      completedAt: DateTime.now().toUtc(),
      calories: estimated == 0 ? null : estimated,
      estimatedCalories: estimated == 0 ? null : estimated,
      averageHr: state.averageHr,
      maxHr: state.maxHr,
      notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
      routineId: state.routine?.id,
      playMode: state.playMode,
      trainingVolumeKg: volume == 0 ? null : volume,
      distanceMeters: state.distanceMeters <= 0 ? null : state.distanceMeters,
    );
    await _ref.read(workoutHistoryProvider.notifier).add(entry);
    stop();
  }

  double _trainingVolumeKg() {
    final routine = state.routine;
    if (routine == null) return 0;
    var total = 0.0;
    for (final ex in routine.exercises) {
      final kg = ex.weightKg ?? 0;
      final reps = ex.reps ?? 0;
      if (kg <= 0 || reps <= 0) continue;
      total += kg * reps * ex.sets;
    }
    return total;
  }

  void discard() => stop();

  void stop() {
    _tick?.cancel();
    _hrPoll?.cancel();
    unawaited(_gpsSub?.cancel());
    _gpsSub = null;
    _gps.reset();
    unawaited(_setDeviceWorkoutMonitoring(false));
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(false);
    state = WorkoutSessionState.idle;
  }

  void _arm() {
    _tick?.cancel();
    _hrPoll?.cancel();
    if (!state.running) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _hrPoll = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollHeartRate());
    });
  }

  void ingestGpsFix(GpsFix fix) {
    if (!state.running || state.completed) return;
    _gps.add(fix);
    final kind = state.activityKind;
    final gpsSteps = (kind == WorkoutActivityKind.running ||
            kind == WorkoutActivityKind.walking)
        ? estimatedStepsFromDistance(
            meters: _gps.distanceMeters,
            running: kind == WorkoutActivityKind.running,
          )
        : null;
    state = _copy(
      distanceMeters: _gps.distanceMeters,
      currentSpeedMps: _gps.currentSpeedMps,
      gpsActive: true,
      routePoints: _gps.normalizedRoute,
      sessionSteps: gpsSteps == 0 ? state.sessionSteps : gpsSteps,
    );
  }

  Future<void> listenGps(Stream<GpsFix> stream) async {
    await _gpsSub?.cancel();
    state = _copy(gpsActive: true, gpsDenied: false);
    _gpsSub = stream.listen(
      ingestGpsFix,
      onError: (_) => state = _copy(gpsActive: false),
    );
  }

  void markGpsDenied() {
    state = _copy(gpsDenied: true, gpsActive: false);
  }

  void recordCadence(int? rpm) {
    if (rpm == null || rpm <= 0) return;
    state = _copy(cadenceRpm: rpm);
  }

  void refreshSessionSteps(int? dailySteps) {
    final baseline = state.baselineSteps;
    if (baseline == null || dailySteps == null) return;
    final delta = dailySteps - baseline;
    if (delta <= 0) return;
    state = _copy(sessionSteps: delta);
  }

  void _resetSensors() {
    _tick?.cancel();
    _hrPoll?.cancel();
    unawaited(_liveHrSub?.cancel());
    _liveHrSub = null;
    unawaited(_gpsSub?.cancel());
    _gpsSub = null;
    _gps.reset();
  }

  Future<void> _setDeviceWorkoutMonitoring(bool active) async {
    if (!mounted) return;
    try {
      final connection = _ref.read(deviceConnectionProvider);
      if (!mounted) return;
      if (!connection.state.isLinked && active) {
        return;
      }
      final adapter = _ref.read(deviceConnectionProvider.notifier).adapter;
      if (active) {
        await adapter.startWorkoutMonitoring();
        if (!mounted) return;
        await _liveHrSub?.cancel();
        _liveHrSub = adapter.watchLiveHeartRate().listen((bpm) {
          if (bpm > 0) recordHeartRate(bpm);
        });
      } else {
        await _liveHrSub?.cancel();
        _liveHrSub = null;
        await adapter.stopWorkoutMonitoring();
      }
    } catch (_) {
      // App-only and unsupported devices keep the workout running.
    }
  }

  Future<void> _pollHeartRate() async {
    if (!mounted || !state.running) return;
    try {
      final reading =
          await _ref.read(deviceConnectionProvider.notifier).adapter.getHeartRate();
      if (reading.hasValue && reading.value != null) {
        recordHeartRate(reading.value);
      }
    } catch (_) {}
  }

  void _goToPhase(int index) {
    if (index >= state.phases.length) {
      finish();
      return;
    }
    if (index < 0) return;
    final elapsed = state.elapsedSeconds();
    state = _copy(
      phaseIndex: index,
      remainingSeconds: state.phases[index].seconds,
      running: true,
      completed: false,
      elapsedAtResumeSeconds: elapsed,
      runningSince: DateTime.now(),
    );
    _arm();
  }

  void _onTick() {
    final phase = state.currentPhase;
    if (phase == null) {
      final elapsed = state.elapsedAtResumeSeconds + 1;
      state = _copy(
        stopwatchElapsed: elapsed,
        elapsedAtResumeSeconds: elapsed,
      );
      return;
    }
    if (phase.kind == WorkoutTimerKind.stopwatch ||
        phase.kind == WorkoutTimerKind.activity) {
      final elapsed = state.elapsedAtResumeSeconds + 1;
      state = _copy(
        stopwatchElapsed: elapsed,
        elapsedAtResumeSeconds: elapsed,
      );
      return;
    }
    final remaining = state.remainingSeconds - 1;
    final elapsed = state.elapsedAtResumeSeconds + 1;
    if (remaining <= 0) {
      _goToPhase(state.phaseIndex + 1);
      return;
    }
    state = _copy(
      remainingSeconds: remaining,
      elapsedAtResumeSeconds: elapsed,
      stopwatchElapsed: elapsed,
    );
  }

  WorkoutSessionState _copy({
    WorkoutRoutine? routine,
    List<TimerPhase>? phases,
    int? phaseIndex,
    int? remainingSeconds,
    bool? running,
    bool? completed,
    int? stopwatchElapsed,
    WorkoutPlayMode? playMode,
    WorkoutActivityKind? activityKind,
    DateTime? runningSince,
    bool clearRunningSince = false,
    int? elapsedAtResumeSeconds,
    String? notes,
    bool? summaryPending,
    List<int>? hrSamples,
    int? hiitWorkSeconds,
    int? hiitRestSeconds,
    int? hiitRounds,
    int? baselineSteps,
    List<WorkoutMetricId>? enabledMetrics,
    double? distanceMeters,
    double? currentSpeedMps,
    bool? gpsActive,
    bool? gpsDenied,
    int? cadenceRpm,
    int? sessionSteps,
    List<({double x, double y})>? routePoints,
    bool clearSpeed = false,
    bool clearCadence = false,
  }) {
    return WorkoutSessionState(
      routine: routine ?? state.routine,
      phases: phases ?? state.phases,
      phaseIndex: phaseIndex ?? state.phaseIndex,
      remainingSeconds: remainingSeconds ?? state.remainingSeconds,
      running: running ?? state.running,
      completed: completed ?? state.completed,
      stopwatchElapsed: stopwatchElapsed ?? state.stopwatchElapsed,
      playMode: playMode ?? state.playMode,
      activityKind: activityKind ?? state.activityKind,
      runningSince: clearRunningSince ? null : (runningSince ?? state.runningSince),
      elapsedAtResumeSeconds:
          elapsedAtResumeSeconds ?? state.elapsedAtResumeSeconds,
      notes: notes ?? state.notes,
      summaryPending: summaryPending ?? state.summaryPending,
      hrSamples: hrSamples ?? state.hrSamples,
      hiitWorkSeconds: hiitWorkSeconds ?? state.hiitWorkSeconds,
      hiitRestSeconds: hiitRestSeconds ?? state.hiitRestSeconds,
      hiitRounds: hiitRounds ?? state.hiitRounds,
      baselineSteps: baselineSteps ?? state.baselineSteps,
      enabledMetrics: enabledMetrics ?? state.enabledMetrics,
      distanceMeters: distanceMeters ?? state.distanceMeters,
      currentSpeedMps:
          clearSpeed ? null : (currentSpeedMps ?? state.currentSpeedMps),
      gpsActive: gpsActive ?? state.gpsActive,
      gpsDenied: gpsDenied ?? state.gpsDenied,
      cadenceRpm: clearCadence ? null : (cadenceRpm ?? state.cadenceRpm),
      sessionSteps: sessionSteps ?? state.sessionSteps,
      routePoints: routePoints ?? state.routePoints,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _hrPoll?.cancel();
    unawaited(_gpsSub?.cancel());
    super.dispose();
  }
}
