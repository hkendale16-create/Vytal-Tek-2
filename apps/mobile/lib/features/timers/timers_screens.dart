import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/time/duration_format.dart';
import '../../domain/models/workout_models.dart';
import '../../timers/clock_controllers.dart';
import '../../workouts/workout_controllers.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

class TimersHubScreen extends ConsumerWidget {
  const TimersHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdown = ref.watch(countdownProvider);
    final stopwatch = ref.watch(stopwatchClockProvider);
    final interval = ref.watch(intervalClockProvider);

    return SectionScaffold(
      title: 'Timers',
      subtitle: 'Countdown, stopwatch, and intervals keep running if you leave this screen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Tile(
            title: 'Timer',
            detail: countdown.running
                ? 'Running · ${formatClock(countdown.remainingSeconds())}'
                : countdown.completed
                    ? 'Complete'
                    : 'Set hours, minutes, and seconds',
            onTap: () => context.push('/timers/countdown'),
          ),
          const SizedBox(height: 10),
          _Tile(
            title: 'Stopwatch',
            detail: stopwatch.running
                ? 'Running · ${formatClockMs(stopwatch.elapsedMs())}'
                : stopwatch.elapsedMs() > 0
                    ? 'Paused · ${formatClockMs(stopwatch.elapsedMs())}'
                    : 'Lap timing',
            onTap: () => context.push('/timers/stopwatch'),
          ),
          const SizedBox(height: 10),
          _Tile(
            title: 'Interval timer',
            detail: interval.running
                ? '${interval.phase.name} · round ${interval.round}'
                : 'Work / rest rounds',
            onTap: () => context.push('/timers/interval'),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: GlassPanel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class CountdownScreen extends ConsumerWidget {
  const CountdownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(countdownProvider);
    final notifier = ref.read(countdownProvider.notifier);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Timer',
      subtitle: 'Continues accurately while you navigate elsewhere.',
      child: Column(
        children: [
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
      ),
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

class StopwatchScreen extends ConsumerWidget {
  const StopwatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stopwatchClockProvider);
    final notifier = ref.read(stopwatchClockProvider.notifier);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Stopwatch',
      subtitle: 'Laps persist while you move around the app.',
      child: Column(
        children: [
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
              ref
                  .read(workoutSessionProvider.notifier)
                  .startActivity(
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
      ),
    );
  }
}

class IntervalTimerScreen extends ConsumerWidget {
  const IntervalTimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(intervalClockProvider);
    final notifier = ref.read(intervalClockProvider.notifier);
    final theme = Theme.of(context);
    final remaining = (state.phaseRemainingMs() / 1000).ceil();

    return SectionScaffold(
      title: 'Interval timer',
      subtitle: 'Work, rest, and rounds for HIIT-style sessions.',
      child: Column(
        children: [
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
      ),
    );
  }
}
