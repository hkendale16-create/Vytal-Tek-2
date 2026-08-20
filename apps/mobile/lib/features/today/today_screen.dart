import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/ambient_background.dart';
import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../devices/connection/device_connection_controller.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/health_metric.dart';
import '../../domain/models/monitoring_mode.dart';
import '../../domain/models/operating_mode.dart';
import '../../monitoring/monitoring_controller.dart';
import '../../state/app_session_controller.dart';
import '../../workouts/workout_controllers.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import 'live_device_stage.dart';
import 'today_health_provider.dart';
import 'today_hero.dart';
import 'training_guidance.dart';
import 'weekly_scorecard_card.dart';
import '../workouts/first_session_panel.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final connection = ref.watch(deviceConnectionProvider);
    final monitoring = ref.watch(monitoringControllerProvider);
    final workout = ref.watch(workoutSessionProvider);
    final history = ref.watch(workoutHistoryProvider);
    final healthAsync = ref.watch(todayHealthProvider);
    final name = session.profile.displayName?.trim();
    final greeting = (name == null || name.isEmpty) ? 'Welcome' : 'Hello, $name';
    final device = connection.activeDevice ?? session.pairedDevice;
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final scorecard = TrainingGuidance.weekScorecard(history.entries);
    final isNewUser = history.entries.isEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayHealthProvider);
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
                          workout.completed;
                      final primaryLabel = workout.summaryPending
                          ? 'View summary'
                          : hasActiveWorkout
                              ? 'Resume workout'
                              : isNewUser
                                  ? 'Start first session'
                                  : 'Start workout';
                      void onPrimary() {
                        if (!hasActiveWorkout && !workout.summaryPending && isNewUser) {
                          context.push('/workouts');
                          return;
                        }
                        context.push(
                          workout.summaryPending
                              ? '/workouts/summary'
                              : hasActiveWorkout
                                  ? '/workouts/active'
                                  : '/workouts',
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
                                onTap: () => context.go('/vitals'),
                              ),
                              HudAction(
                                key: const Key('today-analytics'),
                                icon: Icons.insights_outlined,
                                label: 'Analytics',
                                onTap: () => context.push('/analytics'),
                              ),
                              HudAction(
                                icon: Icons.auto_awesome_outlined,
                                label: 'Plans',
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
