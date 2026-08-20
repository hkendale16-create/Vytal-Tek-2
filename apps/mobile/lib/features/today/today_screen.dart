import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/ambient_background.dart';
import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../devices/connection/device_connection_controller.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/fitness_hub_models.dart';
import '../../domain/models/health_metric.dart';
import '../../domain/models/monitoring_mode.dart';
import '../../domain/models/operating_mode.dart';
import '../../fitness/calendar_controller.dart';
import '../../fitness/progress_analytics.dart';
import '../../fitness/today_plan_launcher.dart';
import '../../monitoring/monitoring_controller.dart';
import '../../state/app_session_controller.dart';
import '../../workouts/workout_controllers.dart';
import '../fitness/upgrade_prompts.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../workouts/first_session_panel.dart';
import 'live_device_stage.dart';
import 'today_health_provider.dart';
import 'today_hero.dart';
import 'training_guidance.dart';
import 'weekly_scorecard_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final connection = ref.watch(deviceConnectionProvider);
    final monitoring = ref.watch(monitoringControllerProvider);
    final workout = ref.watch(workoutSessionProvider);
    final history = ref.watch(workoutHistoryProvider);
    final calendar = ref.watch(fitnessCalendarProvider);
    final healthAsync = ref.watch(todayHealthProvider);
    final name = session.profile.displayName?.trim();
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final greeting = (name == null || name.isEmpty)
        ? timeGreeting
        : '$timeGreeting, $name';
    final device = connection.activeDevice ?? session.pairedDevice;
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final scorecard = TrainingGuidance.weekScorecard(history.entries);
    final isNewUser = history.entries.isEmpty;
    final deviceFree = session.operatingMode == OperatingMode.appOnly &&
        device == null &&
        !session.demoModeEnabled;
    final todayEvent = todaysPlanEvent(calendar);
    final weekStart = TrainingGuidance.startOfWeek();
    final progress = ProgressAnalytics.build(
      history: history.entries,
      range: ProgressRange.d7,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayHealthProvider);
        await ref.read(fitnessCalendarProvider.notifier).syncHistoryIntoCalendar();
        await ref.read(todayHealthProvider.future);
      },
      child: Stack(
        children: [
          const AnimatedAmbientBackground(intensity: 0.1),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                toolbarHeight: 72,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: VytalColors.teal,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(greeting),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'Devices',
                    onPressed: () => context.push('/devices'),
                    icon: const Icon(Icons.watch_outlined),
                  ),
                ],
              ),
              if (deviceFree)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverToBoxAdapter(
                    child: _DeviceFreeToday(
                      todayEvent: todayEvent,
                      weekStart: weekStart,
                      calendar: calendar,
                      historyEmpty: isNewUser,
                      progress: progress,
                      scorecard: scorecard,
                      totalWorkouts: history.entries.length,
                      hasActiveWorkout: workout.running ||
                          workout.summaryPending ||
                          workout.completed ||
                          workout.hasProgress,
                      summaryPending: workout.summaryPending,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverToBoxAdapter(
                    child: healthAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (error, _) => EmptyMetricCard(
                        title: 'Today unavailable',
                        message: 'Could not load health surface. Pull to retry.',
                      ),
                      data: (health) {
                        final headline = TrainingGuidance.dailyHeadline(
                          readinessScore: health.readinessScore,
                          operatingMode: session.operatingMode,
                          hasWearableContext: health.hasWearableContext,
                        );
                        final hasActiveWorkout = workout.running ||
                            workout.summaryPending ||
                            workout.completed ||
                            workout.hasProgress;
                        final primaryLabel = TodayPlanLauncher.primaryLabel(
                          event: todayEvent,
                          summaryPending: workout.summaryPending,
                          hasActiveWorkout: hasActiveWorkout,
                          isNewUser: isNewUser,
                          readinessScore: health.readinessScore,
                        );
                        void onPrimary() {
                          TodayPlanLauncher.startFromToday(
                            context: context,
                            ref: ref,
                            event: todayEvent,
                            readinessScore: health.readinessScore,
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TodayHero(
                              headline: headline,
                              guidance: health.readinessMessage,
                              readinessScore: health.readinessScore,
                              provenance: health.readinessScore == null
                                  ? null
                                  : health.provenance,
                              primaryLabel: primaryLabel,
                              onPrimary: onPrimary,
                              secondaryLabel: 'View analytics',
                              secondaryKey: const Key('today-view-analytics'),
                              onSecondary: () => context.push('/analytics'),
                            ),
                            if (isNewUser && !hasActiveWorkout) ...[
                              const SizedBox(height: 12),
                              const FirstSessionPanel(),
                            ],
                            const SizedBox(height: 12),
                            _TodayPlanCard(
                              event: todayEvent,
                              onStart: hasActiveWorkout ||
                                      workout.summaryPending ||
                                      todayEvent == null ||
                                      todayEvent.isRest ||
                                      todayEvent.isCompleted
                                  ? null
                                  : () => TodayPlanLauncher.startFromToday(
                                        context: context,
                                        ref: ref,
                                        event: todayEvent,
                                        readinessScore: health.readinessScore,
                                      ),
                            ),
                            if (health.readinessScore != null &&
                                todayEvent != null &&
                                !todayEvent.isRest) ...[
                              const SizedBox(height: 8),
                              Text(
                                TrainingGuidance.workoutHubHint(
                                  health.readinessScore,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: extras.textMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            WeeklyScorecardCard(scorecard: scorecard),
                            const SizedBox(height: 12),
                            TodayMetricRow(
                              children: [
                                TodayCompactMetric(
                                  label: 'Sleep',
                                  value: health.sleep.hasValue
                                      ? '${health.sleep.value!.inHours}h'
                                      : null,
                                  onTap: () => context.push('/sleep'),
                                ),
                                TodayCompactMetric(
                                  label: 'Heart rate',
                                  value: health.heartRate.hasValue
                                      ? '${health.heartRate.value}'
                                      : null,
                                  unit: 'BPM',
                                  onTap: () => context.push(
                                    '/vitals/${HealthMetricKeys.heartRate}',
                                  ),
                                ),
                                TodayCompactMetric(
                                  label: 'Activity',
                                  value: health.steps?.toString(),
                                  unit: 'steps',
                                  onTap: () => context.push('/activity'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LiveDeviceStage(
                              deviceKind:
                                  device?.kind ?? VytalDeviceKind.smartRing,
                              connected: device != null,
                              demo: session.demoModeEnabled ||
                                  (device?.isDemo ?? false),
                              heartRateBpm: health.heartRate.hasValue
                                  ? health.heartRate.value
                                  : null,
                              onTap: () => context.push('/devices'),
                            ),
                            Text(
                              device == null
                                  ? (session.demoModeEnabled
                                      ? 'Demo ring · tap to preview live HR'
                                      : 'Works without a device · tap to connect')
                                  : '${device.displayName} · ${connection.state.label}'
                                      '${device.isDemo ? ' · Demo' : ''}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: extras.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                StatusPill(
                                  label: session.operatingMode.label,
                                  emphasis: true,
                                ),
                                if (session.demoModeEnabled)
                                  const StatusPill(
                                    label: 'Demo mode',
                                    emphasis: true,
                                  ),
                                Text(
                                  session.automaticMonitoringEnabled
                                      ? 'Auto · ${monitoring.mode.label}'
                                      : monitoring.mode.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: extras.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            HudActionRail(
                              actions: [
                                HudAction(
                                  icon: Icons.favorite_outline,
                                  label: 'Vitals',
                                  onTap: () => context.push('/vitals'),
                                ),
                                HudAction(
                                  key: const Key('today-analytics'),
                                  icon: Icons.insights_outlined,
                                  label: 'Analytics',
                                  onTap: () => context.push('/analytics'),
                                ),
                                HudAction(
                                  icon: Icons.auto_awesome_outlined,
                                  label: 'Coach',
                                  onTap: () => context.go('/ask'),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceFreeToday extends ConsumerWidget {
  const _DeviceFreeToday({
    required this.todayEvent,
    required this.weekStart,
    required this.calendar,
    required this.historyEmpty,
    required this.progress,
    required this.scorecard,
    required this.totalWorkouts,
    required this.hasActiveWorkout,
    required this.summaryPending,
  });

  final FitnessCalendarEvent? todayEvent;
  final DateTime weekStart;
  final FitnessCalendarState calendar;
  final bool historyEmpty;
  final ProgressSnapshot progress;
  final WeeklyScorecard scorecard;
  final int totalWorkouts;
  final bool hasActiveWorkout;
  final bool summaryPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryLabel = TodayPlanLauncher.primaryLabel(
      event: todayEvent,
      summaryPending: summaryPending,
      hasActiveWorkout: hasActiveWorkout,
      isNewUser: historyEmpty,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TodayPlanCard(
          event: todayEvent,
          onStart: hasActiveWorkout ||
                  summaryPending ||
                  todayEvent == null ||
                  todayEvent!.isRest ||
                  todayEvent!.isCompleted
              ? null
              : () => TodayPlanLauncher.startFromToday(
                    context: context,
                    ref: ref,
                    event: todayEvent,
                  ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => TodayPlanLauncher.startFromToday(
            context: context,
            ref: ref,
            event: todayEvent,
          ),
          child: Text(primaryLabel),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push('/workouts'),
          child: const Text('Quick Start'),
        ),
        if (historyEmpty) ...[
          const SizedBox(height: 12),
          const FirstSessionPanel(),
        ],
        const SizedBox(height: 20),
        Text('THIS WEEK', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        _WeekStrip(weekStart: weekStart, calendar: calendar),
        const SizedBox(height: 20),
        Text('PROGRESS', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${progress.workouts} workouts this week',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.setsCompleted} sets completed',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.strengthDeltas.where((p) => p.deltaKg != null && p.deltaKg! > 0).length} PRs',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.push('/fitness/progress'),
                child: const Text('Open Progress'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        WeeklyScorecardCard(scorecard: scorecard),
        const SizedBox(height: 20),
        Text('VYTAL COACH', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                todayEvent == null
                    ? 'Ready for today’s workout?'
                    : 'Ready for ${todayEvent!.title}?',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: () => context.go('/ask'),
                child: const Text('Ask Coach'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HudActionRail(
          actions: [
            HudAction(
              icon: Icons.calendar_month_outlined,
              label: 'Calendar',
              onTap: () => context.push('/fitness/calendar'),
            ),
            HudAction(
              icon: Icons.location_on_outlined,
              label: 'Gym',
              onTap: () => context.push('/fitness/gyms'),
            ),
            HudAction(
              key: const Key('today-view-analytics'),
              icon: Icons.insights_outlined,
              label: 'Progress',
              onTap: () => context.push('/fitness/progress'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: StatusPill(label: 'App-Only', emphasis: true),
        ),
        const SizedBox(height: 16),
        DeviceFunnelCard(completedWorkouts: totalWorkouts),
      ],
    );
  }
}

class _TodayPlanCard extends StatelessWidget {
  const _TodayPlanCard({required this.event, this.onStart});

  final FitnessCalendarEvent? event;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = event?.isRest == true
        ? 'Rest Day'
        : (event?.title ?? 'Open training day');
    final meta = event == null
        ? 'Pick a plan or Quick Start when you are ready'
        : event!.isRest
            ? 'Recovery on the calendar'
            : [
                if (event!.durationMinutes != null)
                  '~${event!.durationMinutes} min',
                if (event!.notes != null && event!.notes!.isNotEmpty)
                  event!.notes!,
              ].join(' · ');

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY’S PLAN',
            style: theme.textTheme.labelSmall?.copyWith(
              color: VytalColors.teal,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(meta, style: theme.textTheme.bodyMedium),
          if (event != null && event!.isCompleted) ...[
            const SizedBox(height: 8),
            const StatusPill(label: 'Completed ✓', emphasis: true),
          ],
          if (onStart != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onStart,
                child: const Text('Start this session'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.weekStart, required this.calendar});

  final DateTime weekStart;
  final FitnessCalendarState calendar;

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = weekStart.add(Duration(days: i));
                  final events = calendar.forDay(day);
                  final isToday = day == todayKey;
                  final completed = events.any((e) => e.isCompleted);
                  final rest = events.any((e) => e.isRest) && !completed;
                  final planned = events.isNotEmpty && !completed && !rest;
                  final label = completed
                      ? '✓'
                      : rest
                          ? 'Rest'
                          : isToday
                              ? 'Today'
                              : planned
                                  ? 'Plan'
                                  : '—';
                  return Column(
                    children: [
                      Text(
                        _labels[i],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isToday ? VytalColors.teal : null,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: isToday ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
