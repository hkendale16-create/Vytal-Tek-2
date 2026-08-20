import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../analytics/conversion_analytics.dart';
import '../devices/connection/device_connection_controller.dart';
import '../domain/devices/device_connection_state.dart';
import '../domain/models/entitlements.dart';
import '../domain/models/workout_models.dart';
import '../fitness/calendar_controller.dart';
import '../monitoring/monitoring_controller.dart';
import '../state/app_session_controller.dart';
import '../timers/clock_controllers.dart';
import 'active_workout_draft.dart';
import 'workout_gps.dart';
import 'workout_metrics.dart';
import 'workout_prefs.dart';

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

  Future<WorkoutRoutine?> duplicateCustom(String id) async {
    WorkoutRoutine? match;
    for (final routine in state.routines) {
      if (routine.id == id) match = routine;
    }
    if (match == null || match.builtIn) return null;
    return addCustomRoutine(
      match.copyWith(
        id: '',
        name: '${match.name} copy',
      ),
    );
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

  bool get isResting => currentPhase?.kind == WorkoutTimerKind.rest;

  bool get usesSetLogger {
    final kind = activityKind;
    if (kind == WorkoutActivityKind.hiit) return false;
    if (kind?.usesStrengthSets ?? false) return true;
    return kind == WorkoutActivityKind.custom &&
        (routine?.exercises.isNotEmpty ?? false);
  }

  List<WorkoutSetLog> get setLogs => [
        for (final phase in phases)
          if (phase.kind == WorkoutTimerKind.exercise &&
              phase.exerciseName != null)
            WorkoutSetLog(
              exerciseName: phase.exerciseName!,
              setNumber: phase.setNumber ?? 0,
              setType: phase.setType,
              completed: phase.completed,
              reps: phase.reps,
              weightKg: phase.weightKg,
              durationSeconds: phase.isTimedHold ? phase.seconds : null,
            ),
      ];

  List<TimerPhase> exerciseSets(String exerciseId) => phases
      .where(
        (phase) =>
            phase.kind == WorkoutTimerKind.exercise &&
            phase.exerciseId == exerciseId,
      )
      .toList(growable: false);

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
  final controller = WorkoutSessionController(ref);
  unawaited(controller.restoreActiveDraft());
  return controller;
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
  var _draftRestoreAttempted = false;

  /// Cold-start resume for in-progress sessions that survived process death.
  Future<bool> restoreActiveDraft() async {
    if (_draftRestoreAttempted) return false;
    _draftRestoreAttempted = true;
    if (!mounted) return false;
    if (state.running || state.hasProgress || state.summaryPending) {
      return false;
    }
    final draft = await ActiveWorkoutDraft.load();
    // Provider may have been disposed, or a live session started during the await.
    if (!mounted) return false;
    if (state.running || state.hasProgress || state.summaryPending) {
      return false;
    }
    if (draft == null) return false;
    // Ignore stale drafts older than 24h.
    if (DateTime.now().toUtc().difference(draft.savedAt) >
        const Duration(hours: 24)) {
      await ActiveWorkoutDraft.clear();
      return false;
    }

    final kind = draft.activityKind;
    if (draft.setLogs.isNotEmpty || kind.usesStrengthSets) {
      _restoreStrengthDraft(draft);
    } else {
      _restoreActivityDraft(draft);
    }
    return mounted && (state.hasProgress || state.routine != null);
  }

  void _restoreStrengthDraft(ActiveWorkoutDraft draft) {
    if (!mounted) return;
    final uuid = const Uuid();
    final byExercise = <String, List<WorkoutSetLog>>{};
    for (final log in draft.setLogs) {
      byExercise.putIfAbsent(log.exerciseName, () => []).add(log);
    }
    final exercises = <WorkoutExercise>[];
    for (final entry in byExercise.entries) {
      final logs = [...entry.value]
        ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
      final last = logs.last;
      exercises.add(
        WorkoutExercise(
          id: uuid.v4(),
          name: entry.key,
          sets: logs.map((l) => l.setNumber).fold<int>(0, (m, n) => n > m ? n : m)
              .clamp(1, 20),
          reps: last.reps,
          weightKg: last.weightKg,
          durationSeconds: last.durationSeconds,
          restSeconds: 60,
        ),
      );
    }
    final routine = WorkoutRoutine(
      id: draft.routineId ?? 'restored-${draft.activityKind.name}',
      name: draft.routineName ?? draft.activityKind.label,
      exercises: exercises,
      activityKind: draft.activityKind,
      source: 'restored',
    );
    final phases = List<TimerPhase>.from(buildPhases(routine));
    for (var i = 0; i < phases.length; i++) {
      final phase = phases[i];
      if (phase.kind != WorkoutTimerKind.exercise) continue;
      WorkoutSetLog? match;
      for (final log in draft.setLogs) {
        if (log.exerciseName == phase.exerciseName &&
            log.setNumber == phase.setNumber &&
            log.completed) {
          match = log;
          break;
        }
      }
      if (match == null) continue;
      phases[i] = phase.copyWith(
        completed: true,
        reps: match.reps,
        weightKg: match.weightKg,
        setType: match.setType,
      );
    }
    var index = phases.indexWhere(
      (p) => p.kind == WorkoutTimerKind.exercise && !p.completed,
    );
    if (index < 0) index = 0;
    if (!mounted) return;
    _resetSensors();
    state = WorkoutSessionState(
      routine: routine,
      phases: phases,
      phaseIndex: index.clamp(0, phases.isEmpty ? 0 : phases.length - 1),
      remainingSeconds: phases.isEmpty ? 0 : phases[index.clamp(0, phases.length - 1)].seconds,
      running: false,
      completed: false,
      playMode: WorkoutPlayMode.routine,
      activityKind: draft.activityKind,
      elapsedAtResumeSeconds: draft.elapsedSeconds,
      notes: draft.notes,
      distanceMeters: draft.distanceMeters,
    );
  }

  void _restoreActivityDraft(ActiveWorkoutDraft draft) {
    if (!mounted) return;
    final kind = draft.activityKind;
    final label = draft.routineName ?? kind.label;
    _resetSensors();
    if (!mounted) return;
    state = WorkoutSessionState(
      routine: WorkoutRoutine(
        id: draft.routineId ?? 'activity-${kind.name}',
        name: label,
        exercises: const [],
        activityKind: kind,
        source: 'restored',
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
      running: false,
      completed: false,
      playMode: WorkoutPlayMode.activity,
      activityKind: kind,
      elapsedAtResumeSeconds: draft.elapsedSeconds,
      notes: draft.notes,
      distanceMeters: draft.distanceMeters,
    );
  }

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
    if (kind.usesStrengthSets) {
      startStrengthDraft(name: label, kind: kind);
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

  void startStrengthDraft({
    String? name,
    WorkoutActivityKind kind = WorkoutActivityKind.strength,
  }) {
    final resolved = kind.usesStrengthSets ? kind : WorkoutActivityKind.strength;
    final label = name ?? resolved.label;
    _resetSensors();
    state = WorkoutSessionState(
      routine: WorkoutRoutine(
        id: 'activity-${resolved.name}',
        name: label,
        exercises: const [],
        activityKind: resolved,
        source: 'activity',
      ),
      phases: const [],
      phaseIndex: 0,
      remainingSeconds: 0,
      running: true,
      completed: false,
      playMode: WorkoutPlayMode.routine,
      activityKind: resolved,
      runningSince: DateTime.now(),
    );
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(true);
    _arm();
    unawaited(_setDeviceWorkoutMonitoring(true));
  }

  void addExerciseToSession(WorkoutExercise exercise) {
    final kind = state.activityKind ?? WorkoutActivityKind.strength;
    final current = state.routine ??
        WorkoutRoutine(
          id: 'activity-${kind.name}',
          name: kind.label,
          exercises: const [],
          activityKind: kind,
          source: 'activity',
        );
    final routine = current.copyWith(
      exercises: [...current.exercises, exercise],
    );
    final previous = state.phases;
    final phases = List<TimerPhase>.from(buildPhases(routine));
    for (var i = 0; i < phases.length; i++) {
      final next = phases[i];
      TimerPhase? match;
      for (final old in previous) {
        if (old.kind == next.kind &&
            old.exerciseId == next.exerciseId &&
            old.setNumber == next.setNumber) {
          match = old;
          break;
        }
      }
      if (match == null) continue;
      phases[i] = next.copyWith(
        completed: match.completed,
        setType: match.setType,
        reps: match.reps,
        weightKg: match.weightKg,
        seconds: match.isTimedHold ? match.seconds : next.seconds,
      );
    }
    final wasEmpty = previous.isEmpty;
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

  void addSetToCurrentExercise({WorkoutSetType type = WorkoutSetType.working}) {
    final id = state.currentPhase?.exerciseId ??
        (state.routine == null || state.routine!.exercises.isEmpty
            ? null
            : state.routine!.exercises.last.id);
    if (id == null) return;
    addSetToExercise(id, type: type);
  }

  void addSetToExercise(
    String exerciseId, {
    WorkoutSetType type = WorkoutSetType.working,
  }) {
    final routine = state.routine;
    if (routine == null) return;
    final exercises = [
      for (final ex in routine.exercises)
        if (ex.id == exerciseId) ex.copyWith(sets: ex.sets + 1) else ex,
    ];
    final updatedEx = exercises.where((e) => e.id == exerciseId);
    if (updatedEx.isEmpty) return;
    final exercise = updatedEx.first;
    final newSet = exercise.sets;
    final phases = [
      for (final p in state.phases)
        if (p.exerciseId == exerciseId)
          p.copyWith(
            setsTotal: newSet,
            label: p.kind == WorkoutTimerKind.exercise && p.setNumber != null
                ? '${p.exerciseName} · set ${p.setNumber}/$newSet'
                : p.label,
          )
        else
          p,
    ];
    var lastIndex = phases.lastIndexWhere((p) => p.exerciseId == exerciseId);
    if (lastIndex < 0) lastIndex = phases.length - 1;
    final workSeconds =
        exercise.durationSeconds ?? ((exercise.reps ?? 10) * 3);
    final insert = <TimerPhase>[
      TimerPhase(
        kind: WorkoutTimerKind.exercise,
        label: '${exercise.name} · set $newSet/$newSet',
        seconds: workSeconds.clamp(5, 600),
        exerciseId: exerciseId,
        exerciseName: exercise.name,
        setNumber: newSet,
        setsTotal: newSet,
        reps: exercise.reps,
        weightKg: exercise.weightKg,
        muscleGroup: exercise.muscleGroup,
        equipment: exercise.equipment,
        setType: type,
      ),
    ];
    if (exercise.restSeconds > 0) {
      insert.add(
        TimerPhase(
          kind: WorkoutTimerKind.rest,
          label: 'Rest',
          seconds: exercise.restSeconds,
          exerciseId: exerciseId,
          exerciseName: exercise.name,
          setNumber: newSet,
          setsTotal: newSet,
          muscleGroup: exercise.muscleGroup,
          equipment: exercise.equipment,
        ),
      );
    }
    if (lastIndex < 0) {
      phases.addAll(insert);
    } else {
      phases.insertAll(lastIndex + 1, insert);
    }
    state = _copy(
      routine: routine.copyWith(exercises: exercises),
      phases: phases,
      phaseIndex: state.phaseIndex.clamp(0, phases.isEmpty ? 0 : phases.length - 1),
    );
  }

  void updateCurrentSet({
    int? reps,
    double? weightKg,
    int? restSeconds,
    int? durationSeconds,
    WorkoutSetType? setType,
  }) {
    if (state.phases.isEmpty) return;
    updateSetAt(
      state.phaseIndex.clamp(0, state.phases.length - 1),
      reps: reps,
      weightKg: weightKg,
      restSeconds: restSeconds,
      durationSeconds: durationSeconds,
      setType: setType,
    );
  }

  void cycleSetType(int index) {
    if (index < 0 || index >= state.phases.length) return;
    final phase = state.phases[index];
    if (phase.kind != WorkoutTimerKind.exercise) return;
    updateSetAt(index, setType: phase.setType.next);
  }

  void updateSetAt(
    int index, {
    int? reps,
    double? weightKg,
    int? restSeconds,
    int? durationSeconds,
    WorkoutSetType? setType,
  }) {
    if (index < 0 || index >= state.phases.length) return;
    final phase = state.phases[index];
    final phases = [...state.phases];
    var nextRemaining = state.remainingSeconds;
    phases[index] = phase.copyWith(
      reps: reps,
      weightKg: weightKg,
      clearReps: reps != null && reps <= 0,
      clearWeight: weightKg != null && weightKg <= 0,
      seconds: durationSeconds?.clamp(5, 600),
      setType: setType,
    );
    if (durationSeconds != null &&
        index == state.phaseIndex &&
        phase.kind == WorkoutTimerKind.exercise) {
      nextRemaining = durationSeconds.clamp(5, 600);
    }
    if (restSeconds != null) {
      for (var j = index + 1; j < phases.length; j++) {
        if (phases[j].kind == WorkoutTimerKind.rest &&
            phases[j].exerciseId == phase.exerciseId) {
          phases[j] = phases[j].copyWith(seconds: restSeconds);
          break;
        }
      }
    }
    var routine = state.routine;
    if (index == state.phaseIndex &&
        routine != null &&
        phase.exerciseId != null) {
      routine = routine.copyWith(
        exercises: [
          for (final ex in routine.exercises)
            if (ex.id == phase.exerciseId)
              ex.copyWith(
                reps: reps,
                weightKg: weightKg,
                restSeconds: restSeconds,
                durationSeconds: durationSeconds,
                clearReps: reps != null && reps <= 0,
                clearWeight: weightKg != null && weightKg <= 0,
                clearDuration: durationSeconds != null && durationSeconds <= 0,
              )
            else
              ex,
        ],
      );
    }
    state = _copy(
      routine: routine,
      phases: phases,
      remainingSeconds: nextRemaining,
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
    final i = state.phaseIndex;
    final phase = state.phases[i];
    if (phase.kind == WorkoutTimerKind.rest) {
      skip();
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    final phases = [...state.phases];
    phases[i] = phase.copyWith(completed: true);
    state = _copy(phases: phases);
    unawaited(_persistActiveDraft());
    if (i + 1 >= state.phases.length) {
      return;
    }
    _goToPhase(i + 1);
  }

  void skipRest() {
    if (state.currentPhase?.kind != WorkoutTimerKind.rest) return;
    unawaited(HapticFeedback.selectionClick());
    _stopSharedRestTimer();
    skip();
  }

  bool get _autoRestEnabled => _ref.read(workoutPrefsProvider).autoRestEnabled;

  void _startSharedRestTimer(int seconds) {
    if (!_autoRestEnabled || seconds <= 0) return;
    _ref.read(countdownProvider.notifier).startForTotalSeconds(seconds);
  }

  void _stopSharedRestTimer() {
    if (!_autoRestEnabled) return;
    _ref.read(countdownProvider.notifier).pauseWorkoutRest();
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
    _stopSharedRestTimer();
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
    unawaited(_persistActiveDraft());
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
      setLogs: state.setLogs.where((log) => log.completed).toList(),
    );
    await _ref.read(workoutHistoryProvider.notifier).add(entry);
    // Auto-mirror completed sessions into the fitness calendar (no double log).
    try {
      await _ref
          .read(fitnessCalendarProvider.notifier)
          .onWorkoutCompleted(entry);
    } catch (_) {
      // Calendar is additive — never block saving history.
    }
    unawaited(
      _ref.read(conversionAnalyticsProvider).track(
            ConversionEvents.workoutCompleted,
            properties: {
              'activity': entry.activityKind.name,
              'duration_seconds': entry.durationSeconds,
              'sets': entry.setLogs.where((s) => s.completed).length,
            },
          ),
    );
    await ActiveWorkoutDraft.clear();
    stop();
  }

  Future<void> _persistActiveDraft() async {
    if (!state.running && !state.summaryPending && !state.hasProgress) return;
    final kind = state.activityKind ?? WorkoutActivityKind.custom;
    await ActiveWorkoutDraft.persist(
      ActiveWorkoutDraft(
        savedAt: DateTime.now().toUtc(),
        activityKind: kind,
        elapsedSeconds: state.elapsedSeconds(),
        setLogs: state.setLogs.where((log) => log.completed).toList(),
        routineId: state.routine?.id,
        routineName: state.routine?.name,
        notes: state.notes,
        distanceMeters: state.distanceMeters,
      ),
    );
  }

  double _trainingVolumeKg() {
    var total = 0.0;
    for (final phase in state.phases) {
      if (phase.kind != WorkoutTimerKind.exercise || !phase.completed) continue;
      if (!phase.setType.countsForVolume) continue;
      final kg = phase.weightKg ?? 0;
      final reps = phase.reps ?? 0;
      if (kg <= 0 || reps <= 0) continue;
      total += kg * reps;
    }
    return total;
  }

  void discard() {
    unawaited(ActiveWorkoutDraft.clear());
    stop();
  }

  void stop() {
    _tick?.cancel();
    _hrPoll?.cancel();
    _stopSharedRestTimer();
    unawaited(_gpsSub?.cancel());
    _gpsSub = null;
    _gps.reset();
    unawaited(_setDeviceWorkoutMonitoring(false));
    // Intentional stop ends crash-recovery draft; process death leaves it.
    unawaited(ActiveWorkoutDraft.clear());
    if (mounted) {
      _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(false);
      state = WorkoutSessionState.idle;
    }
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
      _stopSharedRestTimer();
      finish();
      return;
    }
    if (index < 0) return;
    final previous = state.currentPhase;
    final phase = state.phases[index];
    if (previous?.kind == WorkoutTimerKind.rest &&
        phase.kind != WorkoutTimerKind.rest) {
      unawaited(HapticFeedback.heavyImpact());
    }
    if (phase.kind == WorkoutTimerKind.rest) {
      _startSharedRestTimer(phase.seconds);
    } else {
      _stopSharedRestTimer();
    }
    final elapsed = state.elapsedSeconds();
    state = _copy(
      phaseIndex: index,
      remainingSeconds: phase.seconds,
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
        phase.kind == WorkoutTimerKind.activity ||
        (phase.kind == WorkoutTimerKind.exercise && state.usesSetLogger)) {
      final elapsed = state.elapsedAtResumeSeconds + 1;
      state = _copy(
        stopwatchElapsed: elapsed,
        elapsedAtResumeSeconds: elapsed,
      );
      return;
    }
    if (phase.kind == WorkoutTimerKind.rest && _autoRestEnabled) {
      final countdown = _ref.read(countdownProvider);
      final elapsed = state.elapsedAtResumeSeconds + 1;
      if (countdown.completed) {
        _goToPhase(state.phaseIndex + 1);
        return;
      }
      state = _copy(
        remainingSeconds: countdown.remainingSeconds(),
        elapsedAtResumeSeconds: elapsed,
        stopwatchElapsed: elapsed,
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
