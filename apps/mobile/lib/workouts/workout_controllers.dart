import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/entitlements.dart';
import '../domain/models/workout_models.dart';
import '../monitoring/monitoring_controller.dart';
import '../state/app_session_controller.dart';

const _routinesKey = 'vytal.workouts.routines.v1';

class WorkoutLibraryState {
  const WorkoutLibraryState({required this.routines});

  final List<WorkoutRoutine> routines;

  List<WorkoutRoutine> get builtIn =>
      routines.where((r) => r.builtIn).toList(growable: false);

  List<WorkoutRoutine> get custom =>
      routines.where((r) => !r.builtIn).toList(growable: false);
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
  }) async {
    final session = _ref.read(appSessionProvider);
    if (!session.entitlements.canUse(EntitlementKeys.workoutsCustom)) {
      return;
    }
    final routine = WorkoutRoutine(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Custom routine' : name.trim(),
      exercises: exercises,
    );
    state = WorkoutLibraryState(routines: [...state.routines, routine]);
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

class WorkoutSessionState {
  const WorkoutSessionState({
    required this.routine,
    required this.phases,
    required this.phaseIndex,
    required this.remainingSeconds,
    required this.running,
    required this.completed,
    this.stopwatchElapsed = 0,
  });

  final WorkoutRoutine? routine;
  final List<TimerPhase> phases;
  final int phaseIndex;
  final int remainingSeconds;
  final bool running;
  final bool completed;
  final int stopwatchElapsed;

  TimerPhase? get currentPhase =>
      phases.isEmpty || phaseIndex >= phases.length ? null : phases[phaseIndex];

  static const idle = WorkoutSessionState(
    routine: null,
    phases: [],
    phaseIndex: 0,
    remainingSeconds: 0,
    running: false,
    completed: false,
  );
}

final workoutSessionProvider =
    StateNotifierProvider<WorkoutSessionController, WorkoutSessionState>((ref) {
  return WorkoutSessionController(ref);
});

/// Exercise / rest / interval / stopwatch engine.
class WorkoutSessionController extends StateNotifier<WorkoutSessionState> {
  WorkoutSessionController(this._ref) : super(WorkoutSessionState.idle);

  final Ref _ref;
  Timer? _tick;

  void startRoutine(WorkoutRoutine routine) {
    final phases = <TimerPhase>[];
    for (final exercise in routine.exercises) {
      for (var set = 1; set <= exercise.sets; set++) {
        final workSeconds = exercise.durationSeconds ??
            ((exercise.reps ?? 10) * 3); // coarse paced reps
        phases.add(
          TimerPhase(
            kind: WorkoutTimerKind.exercise,
            label: '${exercise.name} · set $set/${exercise.sets}',
            seconds: workSeconds.clamp(5, 600),
          ),
        );
        if (exercise.restSeconds > 0 && set < exercise.sets) {
          phases.add(
            TimerPhase(
              kind: WorkoutTimerKind.rest,
              label: 'Rest',
              seconds: exercise.restSeconds,
            ),
          );
        }
      }
    }
    _tick?.cancel();
    state = WorkoutSessionState(
      routine: routine,
      phases: phases,
      phaseIndex: 0,
      remainingSeconds: phases.isEmpty ? 0 : phases.first.seconds,
      running: true,
      completed: phases.isEmpty,
    );
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(true);
    _arm();
  }

  void startStopwatch() {
    _tick?.cancel();
    state = const WorkoutSessionState(
      routine: null,
      phases: [
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
      stopwatchElapsed: 0,
    );
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(true);
    _arm();
  }

  void pause() {
    _tick?.cancel();
    state = _copy(running: false);
  }

  void resume() {
    if (state.completed || state.phases.isEmpty) return;
    state = _copy(running: true);
    _arm();
  }

  void stop() {
    _tick?.cancel();
    _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(false);
    state = WorkoutSessionState.idle;
  }

  void _arm() {
    _tick?.cancel();
    if (!state.running) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    final phase = state.currentPhase;
    if (phase == null) {
      stop();
      return;
    }
    if (phase.kind == WorkoutTimerKind.stopwatch) {
      state = _copy(stopwatchElapsed: state.stopwatchElapsed + 1);
      return;
    }
    if (state.remainingSeconds <= 1) {
      final next = state.phaseIndex + 1;
      if (next >= state.phases.length) {
        _tick?.cancel();
        _ref.read(monitoringControllerProvider.notifier).setWorkoutActive(false);
        state = _copy(
          phaseIndex: next,
          remainingSeconds: 0,
          running: false,
          completed: true,
        );
        return;
      }
      state = _copy(
        phaseIndex: next,
        remainingSeconds: state.phases[next].seconds,
      );
      return;
    }
    state = _copy(remainingSeconds: state.remainingSeconds - 1);
  }

  WorkoutSessionState _copy({
    WorkoutRoutine? routine,
    List<TimerPhase>? phases,
    int? phaseIndex,
    int? remainingSeconds,
    bool? running,
    bool? completed,
    int? stopwatchElapsed,
  }) {
    return WorkoutSessionState(
      routine: routine ?? state.routine,
      phases: phases ?? state.phases,
      phaseIndex: phaseIndex ?? state.phaseIndex,
      remainingSeconds: remainingSeconds ?? state.remainingSeconds,
      running: running ?? state.running,
      completed: completed ?? state.completed,
      stopwatchElapsed: stopwatchElapsed ?? state.stopwatchElapsed,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}
