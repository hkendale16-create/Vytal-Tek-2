import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/time/duration_format.dart';
import '../../domain/models/workout_models.dart';
import '../../timers/clock_controllers.dart';
import '../../workouts/workout_controllers.dart';
import '../../workouts/workout_prefs.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../shared/vytal_controls.dart';

enum TimerHubTab { countdown, stopwatch, interval, rest }

class TimersHubScreen extends ConsumerStatefulWidget {
  const TimersHubScreen({super.key});

  @override
  ConsumerState<TimersHubScreen> createState() => _TimersHubScreenState();
}

class _TimersHubScreenState extends ConsumerState<TimersHubScreen> {
  var _tab = TimerHubTab.countdown;

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'Timers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VytalTabSelector<TimerHubTab>(
            values: TimerHubTab.values,
            selected: _tab,
            labelOf: _tabLabel,
            onChanged: (value) => setState(() => _tab = value),
          ),
          const SizedBox(height: 16),
          switch (_tab) {
            TimerHubTab.countdown => const CountdownPanel(showExpand: true),
            TimerHubTab.stopwatch => const StopwatchPanel(showExpand: true),
            TimerHubTab.interval => const IntervalPanel(showExpand: true),
            TimerHubTab.rest => const RestTimerPanel(),
          },
        ],
      ),
    );
  }

  static String _tabLabel(TimerHubTab tab) => switch (tab) {
        TimerHubTab.countdown => 'Countdown',
        TimerHubTab.stopwatch => 'Stopwatch',
        TimerHubTab.interval => 'Interval',
        TimerHubTab.rest => 'Rest',
      };
}

class CountdownScreen extends ConsumerWidget {
  const CountdownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SectionScaffold(
      title: 'Timer',
      child: CountdownPanel(),
    );
  }
}

class CountdownPanel extends ConsumerWidget {
  const CountdownPanel({super.key, this.showExpand = false});

  final bool showExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(countdownProvider);
    final notifier = ref.read(countdownProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      children: [
        if (showExpand)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/timers/countdown'),
              icon: const Icon(Icons.open_in_full, size: 16),
              label: const Text('Full screen'),
            ),
          ),
        GlassPanel(
          glow: state.running,
          child: Column(
            children: [
              Text(
                formatClock(state.remainingSeconds()),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (state.completed)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: StatusPill(label: 'Complete', emphasis: true),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!state.running) ...[
          _Stepper(
            label: 'Hours',
            value: state.hours,
            onChanged: notifier.setHours,
          ),
          _Stepper(
            label: 'Minutes',
            value: state.minutes,
            onChanged: notifier.setMinutes,
          ),
          _Stepper(
            label: 'Seconds',
            value: state.seconds,
            onChanged: notifier.setSeconds,
          ),
        ],
        SwitchListTile(
          title: const Text('Sound'),
          value: state.soundEnabled,
          onChanged: (v) => notifier.setAlerts(sound: v),
        ),
        SwitchListTile(
          title: const Text('Vibration'),
          value: state.vibrationEnabled,
          onChanged: (v) => notifier.setAlerts(vibration: v),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.running ? notifier.pause : notifier.start,
                child: Text(state.running
                    ? 'Pause'
                    : state.remainingAtResumeMs > 0 &&
                            state.remainingAtResumeMs <
                                state.configuredSeconds * 1000
                        ? 'Resume'
                        : 'Start'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: notifier.reset,
                child: const Text('Reset'),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: notifier.cancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class StopwatchScreen extends ConsumerWidget {
  const StopwatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SectionScaffold(
      title: 'Stopwatch',
      child: StopwatchPanel(),
    );
  }
}

class StopwatchPanel extends ConsumerWidget {
  const StopwatchPanel({super.key, this.showExpand = false});

  final bool showExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stopwatchClockProvider);
    final notifier = ref.read(stopwatchClockProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      children: [
        if (showExpand)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/timers/stopwatch'),
              icon: const Icon(Icons.open_in_full, size: 16),
              label: const Text('Full screen'),
            ),
          ),
        GlassPanel(
          glow: state.running,
          child: Text(
            formatClockMs(state.elapsedMs()),
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.running ? notifier.pause : notifier.start,
                child: Text(state.running
                    ? 'Pause'
                    : state.elapsedMs() > 0
                        ? 'Resume'
                        : 'Start'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: notifier.lap,
                child: const Text('Lap'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: notifier.reset,
          child: const Text('Reset'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () {
            final elapsed = (state.elapsedMs() / 1000).round();
            ref.read(workoutSessionProvider.notifier).startActivity(
                  WorkoutActivityKind.custom,
                  name: 'Timed session',
                  initialElapsedSeconds: elapsed,
                );
            context.push('/workouts/active');
          },
          child: const Text('Attach to Workout'),
        ),
        const SizedBox(height: 16),
        if (state.laps.isEmpty)
          const EmptyMetricCard(
            title: 'No laps yet',
            message: 'Start the stopwatch and tap Lap to record splits.',
          )
        else
          ...state.laps.reversed.map(
            (lap) => ListTile(
              title: Text('Lap ${lap.index}'),
              trailing: Text(formatClockMs(lap.elapsedMs)),
            ),
          ),
      ],
    );
  }
}

class IntervalTimerScreen extends ConsumerWidget {
  const IntervalTimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SectionScaffold(
      title: 'Interval timer',
      child: IntervalPanel(),
    );
  }
}

class IntervalPanel extends ConsumerWidget {
  const IntervalPanel({super.key, this.showExpand = false});

  final bool showExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(intervalClockProvider);
    final notifier = ref.read(intervalClockProvider.notifier);
    final theme = Theme.of(context);
    final remaining = (state.phaseRemainingMs() / 1000).ceil();

    return Column(
      children: [
        if (showExpand)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/timers/interval'),
              icon: const Icon(Icons.open_in_full, size: 16),
              label: const Text('Full screen'),
            ),
          ),
        GlassPanel(
          glow: state.running,
          child: Column(
            children: [
              Text(
                state.phase.name.toUpperCase(),
                style: theme.textTheme.titleMedium,
              ),
              Text(
                formatClock(remaining),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Round ${state.round} / ${state.config.rounds}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'Next: ${state.nextPhase.name}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!state.running) ...[
          _Stepper(
            label: 'Work sec',
            value: state.config.workSeconds,
            onChanged: (v) => notifier.updateConfig(
              state.config.copyWith(workSeconds: v.clamp(5, 600)),
            ),
          ),
          _Stepper(
            label: 'Rest sec',
            value: state.config.restSeconds,
            onChanged: (v) => notifier.updateConfig(
              state.config.copyWith(restSeconds: v.clamp(0, 600)),
            ),
          ),
          _Stepper(
            label: 'Rounds',
            value: state.config.rounds,
            onChanged: (v) => notifier.updateConfig(
              state.config.copyWith(rounds: v.clamp(1, 40)),
            ),
          ),
          _Stepper(
            label: 'Warm-up',
            value: state.config.warmupSeconds,
            onChanged: (v) => notifier.updateConfig(
              state.config.copyWith(warmupSeconds: v.clamp(0, 600)),
            ),
          ),
          _Stepper(
            label: 'Cool-down',
            value: state.config.cooldownSeconds,
            onChanged: (v) => notifier.updateConfig(
              state.config.copyWith(cooldownSeconds: v.clamp(0, 600)),
            ),
          ),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.running ? notifier.pause : notifier.start,
                child: Text(state.running ? 'Pause' : 'Start'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: notifier.skip,
                child: const Text('Skip interval'),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: notifier.stop,
          child: const Text('Stop'),
        ),
      ],
    );
  }
}

class RestTimerPanel extends ConsumerWidget {
  const RestTimerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(workoutPrefsProvider);
    final prefsNotifier = ref.read(workoutPrefsProvider.notifier);
    final countdown = ref.watch(countdownProvider);
    final clock = ref.read(countdownProvider.notifier);
    final theme = Theme.of(context);
    final session = ref.watch(workoutSessionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VytalSectionHeader(
          title: 'Between sets',
          subtitle: 'Shared countdown with sound and vibration when auto-rest is on.',
        ),
        GlassPanel(
          glow: countdown.running,
          accent: VytalColors.caution,
          child: Column(
            children: [
              Text(
                formatClock(
                  countdown.running || countdown.completed
                      ? countdown.remainingSeconds()
                      : prefs.defaultRestSeconds,
                ),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (session.isResting)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Active workout rest · ${session.currentPhase?.exerciseName ?? 'Set'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Auto-start rest after each set'),
          subtitle: const Text('Uses this timer during strength workouts'),
          value: prefs.autoRestEnabled,
          onChanged: prefsNotifier.setAutoRestEnabled,
        ),
        _Stepper(
          label: 'Default rest (sec)',
          value: prefs.defaultRestSeconds,
          onChanged: prefsNotifier.setDefaultRestSeconds,
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            clock.startForTotalSeconds(prefs.defaultRestSeconds);
          },
          child: Text(countdown.running ? 'Restart rest' : 'Start rest'),
        ),
        if (countdown.running)
          TextButton(
            onPressed: clock.pause,
            child: const Text('Pause'),
          ),
        if (session.isResting) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/workouts/active'),
            child: const Text('Return to workout'),
          ),
        ],
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: () => onChanged(value - 1),
          icon: const Icon(Icons.remove),
        ),
        Text('$value', style: Theme.of(context).textTheme.titleLarge),
        IconButton(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
