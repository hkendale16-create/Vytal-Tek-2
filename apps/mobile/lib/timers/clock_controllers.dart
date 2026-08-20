import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wall-clock timers so elapsed time stays accurate across navigation
/// and when the isolate is paused (recomputed from DateTime on resume).
class CountdownState {
  const CountdownState({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.running,
    required this.completed,
    required this.remainingAtResumeMs,
    this.runningSince,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  final int hours;
  final int minutes;
  final int seconds;
  final bool running;
  final bool completed;
  final DateTime? runningSince;
  final int remainingAtResumeMs;
  final bool soundEnabled;
  final bool vibrationEnabled;

  int get configuredSeconds =>
      (hours.clamp(0, 23) * 3600) + (minutes.clamp(0, 59) * 60) + seconds.clamp(0, 59);

  int remainingMs([DateTime? now]) {
    if (completed) return 0;
    return remainingAtResumeMs.clamp(0, configuredSeconds * 1000);
  }

  int remainingSeconds([DateTime? now]) => (remainingMs(now) / 1000).ceil();

  static const idle = CountdownState(
    hours: 0,
    minutes: 2,
    seconds: 0,
    running: false,
    completed: false,
    remainingAtResumeMs: 120000,
  );
}

final countdownProvider =
    StateNotifierProvider<CountdownController, CountdownState>((ref) {
  return CountdownController();
});

class CountdownController extends StateNotifier<CountdownState> {
  CountdownController() : super(CountdownState.idle);

  Timer? _tick;

  void setHours(int value) {
    if (state.running) return;
    final hours = value.clamp(0, 23);
    final configured = (hours * 3600) + (state.minutes * 60) + state.seconds;
    state = CountdownState(
      hours: hours,
      minutes: state.minutes,
      seconds: state.seconds,
      running: false,
      completed: false,
      remainingAtResumeMs: configured * 1000,
      soundEnabled: state.soundEnabled,
      vibrationEnabled: state.vibrationEnabled,
    );
  }

  void setMinutes(int value) {
    if (state.running) return;
    final minutes = value.clamp(0, 59);
    final configured = (state.hours * 3600) + (minutes * 60) + state.seconds;
    state = CountdownState(
      hours: state.hours,
      minutes: minutes,
      seconds: state.seconds,
      running: false,
      completed: false,
      remainingAtResumeMs: configured * 1000,
      soundEnabled: state.soundEnabled,
      vibrationEnabled: state.vibrationEnabled,
    );
  }

  void setSeconds(int value) {
    if (state.running) return;
    final seconds = value.clamp(0, 59);
    final configured = (state.hours * 3600) + (state.minutes * 60) + seconds;
    state = CountdownState(
      hours: state.hours,
      minutes: state.minutes,
      seconds: seconds,
      running: false,
      completed: false,
      remainingAtResumeMs: configured * 1000,
      soundEnabled: state.soundEnabled,
      vibrationEnabled: state.vibrationEnabled,
    );
  }

  void setAlerts({bool? sound, bool? vibration}) {
    state = CountdownState(
      hours: state.hours,
      minutes: state.minutes,
      seconds: state.seconds,
      running: state.running,
      completed: state.completed,
      remainingAtResumeMs: state.remainingAtResumeMs,
      runningSince: state.runningSince,
      soundEnabled: sound ?? state.soundEnabled,
      vibrationEnabled: vibration ?? state.vibrationEnabled,
    );
  }

  void start() {
    final total = state.configuredSeconds;
    if (total <= 0) return;
    final remaining = state.completed
        ? total * 1000
        : (state.running ? state.remainingMs() : state.remainingAtResumeMs);
    if (remaining <= 0) return;
    state = CountdownState(
      hours: state.hours,
      minutes: state.minutes,
      seconds: state.seconds,
      running: true,
      completed: false,
      remainingAtResumeMs: remaining,
      runningSince: DateTime.now(),
      soundEnabled: state.soundEnabled,
      vibrationEnabled: state.vibrationEnabled,
    );
    _arm();
  }

  void pause() {
    if (!state.running) return;
    state = CountdownState(
      hours: state.hours,
      minutes: state.minutes,
      seconds: state.seconds,
      running: false,
      completed: false,
      remainingAtResumeMs: state.remainingMs(),
      soundEnabled: state.soundEnabled,
      vibrationEnabled: state.vibrationEnabled,
    );
    _tick?.cancel();
  }

  void reset() {
    _tick?.cancel();
    final total = state.configuredSeconds * 1000;
    state = CountdownState(
      hours: state.hours,
      minutes: state.minutes,
      seconds: state.seconds,
      running: false,
      completed: false,
      remainingAtResumeMs: total,
      soundEnabled: state.soundEnabled,
      vibrationEnabled: state.vibrationEnabled,
    );
  }

  void cancel() => reset();

  /// Configure h/m/s from a single duration and optionally start (workout rest).
  void configureTotalSeconds(int totalSeconds, {bool startRunning = false}) {
    final clamped = totalSeconds.clamp(1, 23 * 3600 + 59 * 60 + 59);
    final hours = clamped ~/ 3600;
    final minutes = (clamped % 3600) ~/ 60;
    final seconds = clamped % 60;
    _tick?.cancel();
    state = CountdownState(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      running: startRunning,
      completed: false,
      remainingAtResumeMs: clamped * 1000,
      runningSince: startRunning ? DateTime.now() : null,
      soundEnabled: state.soundEnabled,
      vibrationEnabled: state.vibrationEnabled,
    );
    if (startRunning) _arm();
  }

  void startForTotalSeconds(int totalSeconds) {
    configureTotalSeconds(totalSeconds, startRunning: true);
  }

  void pauseWorkoutRest() {
    if (!state.running) return;
    pause();
  }

  void _arm() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) => _onTick());
  }

  void _onTick() {
    if (!state.running) return;
    final rem = state.remainingAtResumeMs - 200;
    if (rem <= 0) {
      _tick?.cancel();
      state = CountdownState(
        hours: state.hours,
        minutes: state.minutes,
        seconds: state.seconds,
        running: false,
        completed: true,
        remainingAtResumeMs: 0,
        soundEnabled: state.soundEnabled,
        vibrationEnabled: state.vibrationEnabled,
      );
      _alert();
    } else {
      // Re-emit so listeners refresh remaining time from wall clock.
      state = CountdownState(
        hours: state.hours,
        minutes: state.minutes,
        seconds: state.seconds,
        running: true,
        completed: false,
        remainingAtResumeMs: rem,
        runningSince: state.runningSince,
        soundEnabled: state.soundEnabled,
        vibrationEnabled: state.vibrationEnabled,
      );
    }
  }

  Future<void> _alert() async {
    if (state.vibrationEnabled) {
      await HapticFeedback.heavyImpact();
    }
    if (state.soundEnabled) {
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

class StopwatchLap {
  const StopwatchLap({required this.index, required this.elapsedMs});

  final int index;
  final int elapsedMs;
}

class StopwatchClockState {
  const StopwatchClockState({
    required this.running,
    required this.elapsedAtResumeMs,
    required this.laps,
    this.runningSince,
  });

  final bool running;
  final DateTime? runningSince;
  final int elapsedAtResumeMs;
  final List<StopwatchLap> laps;

  int elapsedMs([DateTime? now]) => math.max(0, elapsedAtResumeMs);

  static const idle = StopwatchClockState(
    running: false,
    elapsedAtResumeMs: 0,
    laps: [],
  );
}

final stopwatchClockProvider =
    StateNotifierProvider<StopwatchClockController, StopwatchClockState>((ref) {
  return StopwatchClockController();
});

class StopwatchClockController extends StateNotifier<StopwatchClockState> {
  StopwatchClockController() : super(StopwatchClockState.idle);

  Timer? _tick;

  void start() {
    if (state.running) return;
    state = StopwatchClockState(
      running: true,
      elapsedAtResumeMs: state.elapsedAtResumeMs,
      runningSince: DateTime.now(),
      laps: state.laps,
    );
    _arm();
  }

  void pause() {
    if (!state.running) return;
    _tick?.cancel();
    state = StopwatchClockState(
      running: false,
      elapsedAtResumeMs: state.elapsedMs(),
      laps: state.laps,
    );
  }

  void reset() {
    _tick?.cancel();
    state = StopwatchClockState.idle;
  }

  void lap() {
    final elapsed = state.elapsedMs();
    if (elapsed <= 0) return;
    state = StopwatchClockState(
      running: state.running,
      elapsedAtResumeMs: state.elapsedAtResumeMs,
      runningSince: state.runningSince,
      laps: [
        ...state.laps,
        StopwatchLap(index: state.laps.length + 1, elapsedMs: elapsed),
      ],
    );
  }

  void _arm() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!state.running) return;
      state = StopwatchClockState(
        running: true,
        elapsedAtResumeMs: state.elapsedAtResumeMs + 80,
        runningSince: state.runningSince,
        laps: state.laps,
      );
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

enum IntervalPhaseKind { warmup, work, rest, cooldown, done }

class IntervalConfig {
  const IntervalConfig({
    this.workSeconds = 30,
    this.restSeconds = 30,
    this.rounds = 8,
    this.warmupSeconds = 0,
    this.cooldownSeconds = 0,
  });

  final int workSeconds;
  final int restSeconds;
  final int rounds;
  final int warmupSeconds;
  final int cooldownSeconds;

  IntervalConfig copyWith({
    int? workSeconds,
    int? restSeconds,
    int? rounds,
    int? warmupSeconds,
    int? cooldownSeconds,
  }) {
    return IntervalConfig(
      workSeconds: workSeconds ?? this.workSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      rounds: rounds ?? this.rounds,
      warmupSeconds: warmupSeconds ?? this.warmupSeconds,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    );
  }
}

class IntervalClockState {
  const IntervalClockState({
    required this.config,
    required this.running,
    required this.completed,
    required this.round,
    required this.phase,
    required this.phaseRemainingAtStartMs,
    this.phaseStartedAt,
  });

  final IntervalConfig config;
  final bool running;
  final bool completed;
  final int round;
  final IntervalPhaseKind phase;
  final DateTime? phaseStartedAt;
  final int phaseRemainingAtStartMs;

  int phaseRemainingMs([DateTime? now]) {
    if (completed || phase == IntervalPhaseKind.done) return 0;
    return phaseRemainingAtStartMs.clamp(0, 24 * 3600 * 1000);
  }

  IntervalPhaseKind get nextPhase {
    return switch (phase) {
      IntervalPhaseKind.warmup => IntervalPhaseKind.work,
      IntervalPhaseKind.work => round >= config.rounds
          ? (config.cooldownSeconds > 0
              ? IntervalPhaseKind.cooldown
              : IntervalPhaseKind.done)
          : IntervalPhaseKind.rest,
      IntervalPhaseKind.rest => IntervalPhaseKind.work,
      IntervalPhaseKind.cooldown => IntervalPhaseKind.done,
      IntervalPhaseKind.done => IntervalPhaseKind.done,
    };
  }

  static const idle = IntervalClockState(
    config: IntervalConfig(),
    running: false,
    completed: false,
    round: 1,
    phase: IntervalPhaseKind.work,
    phaseRemainingAtStartMs: 30000,
  );
}

final intervalClockProvider =
    StateNotifierProvider<IntervalClockController, IntervalClockState>((ref) {
  return IntervalClockController();
});

class IntervalClockController extends StateNotifier<IntervalClockState> {
  IntervalClockController() : super(IntervalClockState.idle);

  Timer? _tick;

  void updateConfig(IntervalConfig config) {
    if (state.running) return;
    final first = config.warmupSeconds > 0
        ? IntervalPhaseKind.warmup
        : IntervalPhaseKind.work;
    state = IntervalClockState(
      config: config,
      running: false,
      completed: false,
      round: 1,
      phase: first,
      phaseRemainingAtStartMs: _secondsFor(first, 1, config) * 1000,
    );
  }

  void start() {
    if (state.completed) {
      updateConfig(state.config);
    }
    state = IntervalClockState(
      config: state.config,
      running: true,
      completed: false,
      round: state.round,
      phase: state.phase == IntervalPhaseKind.done
          ? (state.config.warmupSeconds > 0
              ? IntervalPhaseKind.warmup
              : IntervalPhaseKind.work)
          : state.phase,
      phaseStartedAt: DateTime.now(),
      phaseRemainingAtStartMs: state.completed
          ? _secondsFor(
                  state.config.warmupSeconds > 0
                      ? IntervalPhaseKind.warmup
                      : IntervalPhaseKind.work,
                  1,
                  state.config) *
              1000
          : state.phaseRemainingMs(),
    );
    _arm();
  }

  void pause() {
    if (!state.running) return;
    _tick?.cancel();
    state = IntervalClockState(
      config: state.config,
      running: false,
      completed: false,
      round: state.round,
      phase: state.phase,
      phaseRemainingAtStartMs: state.phaseRemainingMs(),
    );
  }

  void skip() => _advance(force: true);

  void stop() {
    _tick?.cancel();
    updateConfig(state.config);
  }

  int _secondsFor(IntervalPhaseKind phase, int round, IntervalConfig config) {
    return switch (phase) {
      IntervalPhaseKind.warmup => config.warmupSeconds,
      IntervalPhaseKind.work => config.workSeconds,
      IntervalPhaseKind.rest => config.restSeconds,
      IntervalPhaseKind.cooldown => config.cooldownSeconds,
      IntervalPhaseKind.done => 0,
    };
  }

  void _advance({bool force = false}) {
    if (state.completed && !force) return;
    var round = state.round;
    var phase = state.phase;
    if (phase == IntervalPhaseKind.work && round < state.config.rounds) {
      phase = IntervalPhaseKind.rest;
    } else if (phase == IntervalPhaseKind.work) {
      phase = state.config.cooldownSeconds > 0
          ? IntervalPhaseKind.cooldown
          : IntervalPhaseKind.done;
    } else if (phase == IntervalPhaseKind.rest) {
      round += 1;
      phase = IntervalPhaseKind.work;
    } else if (phase == IntervalPhaseKind.warmup) {
      phase = IntervalPhaseKind.work;
      round = 1;
    } else {
      phase = IntervalPhaseKind.done;
    }

    if (phase == IntervalPhaseKind.done) {
      _tick?.cancel();
      state = IntervalClockState(
        config: state.config,
        running: false,
        completed: true,
        round: round,
        phase: IntervalPhaseKind.done,
        phaseRemainingAtStartMs: 0,
      );
      unawaited(HapticFeedback.mediumImpact());
      unawaited(SystemSound.play(SystemSoundType.alert));
      return;
    }

    state = IntervalClockState(
      config: state.config,
      running: state.running || force,
      completed: false,
      round: round,
      phase: phase,
      phaseStartedAt: DateTime.now(),
      phaseRemainingAtStartMs: _secondsFor(phase, round, state.config) * 1000,
    );
    if (state.running) _arm();
  }

  void _arm() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!state.running) return;
      final rem = state.phaseRemainingAtStartMs - 200;
      if (rem <= 0) {
        _advance();
        return;
      }
      state = IntervalClockState(
        config: state.config,
        running: true,
        completed: false,
        round: state.round,
        phase: state.phase,
        phaseStartedAt: state.phaseStartedAt,
        phaseRemainingAtStartMs: rem,
      );
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}
