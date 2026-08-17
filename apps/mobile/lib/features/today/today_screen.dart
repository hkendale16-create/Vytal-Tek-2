import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../devices/connection/device_connection_controller.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../../domain/models/monitoring_mode.dart';
import '../../domain/models/operating_mode.dart';
import '../../monitoring/monitoring_controller.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import 'today_health_provider.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final connection = ref.watch(deviceConnectionProvider);
    final monitoring = ref.watch(monitoringControllerProvider);
    final healthAsync = ref.watch(todayHealthProvider);
    final name = session.profile.displayName?.trim();
    final greeting = (name == null || name.isEmpty) ? 'Welcome' : 'Hello, $name';
    final device = connection.activeDevice ?? session.pairedDevice;
    final theme = Theme.of(context);
    final extras = context.vytalExtras;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayHealthProvider);
        await ref.read(todayHealthProvider.future);
      },
      child: Stack(
        children: [
          const AmbientCanvasGlow(intensity: 1.05),
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
                      final monitoringCaption =
                          session.automaticMonitoringEnabled
                              ? 'Automatic — ${monitoring.mode.label}'
                              : monitoring.mode.label;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'How am I doing today?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: extras.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
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
                                monitoringCaption,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: extras.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 420,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: FloatingHud(
                                    amplitude: 5,
                                    child: ReadinessGauge(
                                      score: health.readinessScore,
                                      size: 248,
                                      label: 'READINESS',
                                      subtitle: health.readinessScore == null
                                          ? null
                                          : health.provenance ==
                                                  DataProvenance.demo
                                              ? 'Demo presentation'
                                              : 'Baseline learning',
                                      provenance: health.readinessScore == null
                                          ? null
                                          : health.provenance,
                                      onTap: () => context.push('/recovery'),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(-1.0, -0.82),
                                  child: FloatingHud(
                                    delay: const Duration(milliseconds: 160),
                                    child: HudMetricChip(
                                      label: 'Heart Rate',
                                      value: health.heartRate.hasValue
                                          ? '${health.heartRate.value}'
                                          : null,
                                      unit: 'BPM',
                                      icon: Icons.favorite_outline,
                                      provenance: health.heartRate.provenance,
                                      onTap: () => context.push(
                                        '/vitals/${HealthMetricKeys.heartRate}',
                                      ),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(1.0, -0.48),
                                  child: FloatingHud(
                                    delay: const Duration(milliseconds: 380),
                                    child: HudMetricChip(
                                      label: 'Sleep',
                                      value: health.sleep.hasValue
                                          ? '${health.sleep.value!.inHours}h'
                                          : null,
                                      unit: '',
                                      icon: Icons.bedtime_outlined,
                                      provenance: health.sleep.provenance,
                                      onTap: () => context.push('/sleep'),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(-1.0, 0.78),
                                  child: FloatingHud(
                                    delay: const Duration(milliseconds: 620),
                                    child: HudMetricChip(
                                      label: 'Activity',
                                      value: health.steps?.toString(),
                                      unit: health.steps == null ? '' : 'steps',
                                      icon: Icons.directions_run_outlined,
                                      provenance: health.steps == null
                                          ? null
                                          : health.provenance,
                                      onTap: () => context.push('/activity'),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: const Alignment(1.0, 0.62),
                                  child: FloatingHud(
                                    delay: const Duration(milliseconds: 840),
                                    child: HudMetricChip(
                                      label: 'HRV',
                                      value: health.hrv.hasValue
                                          ? '${health.hrv.value}'
                                          : null,
                                      unit: 'ms',
                                      icon: Icons.graphic_eq,
                                      provenance: health.hrv.provenance,
                                      onTap: () => context.push(
                                        '/vitals/${HealthMetricKeys.hrv}',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            health.readinessMessage,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: extras.textMuted,
                            ),
                          ),
                          const SizedBox(height: 18),
                          HudActionRail(
                            actions: [
                              HudAction(
                                icon: Icons.play_arrow_rounded,
                                label: 'Workout',
                                onTap: () => context.push('/workouts/start'),
                              ),
                              HudAction(
                                icon: Icons.favorite_outline,
                                label: 'Vitals',
                                onTap: () => context.go('/vitals'),
                              ),
                              HudAction(
                                icon: Icons.timer_outlined,
                                label: 'Timer',
                                onTap: () => context.push('/timers/countdown'),
                              ),
                              HudAction(
                                icon: Icons.timer_outlined,
                                label: 'Stopwatch',
                                onTap: () => context.push('/timers/stopwatch'),
                              ),
                              HudAction(
                                icon: Icons.note_alt_outlined,
                                label: 'Note',
                                onTap: () => context.push('/notes'),
                              ),
                              HudAction(
                                icon: Icons.auto_awesome_outlined,
                                label: 'Ask Vytal',
                                onTap: () => context.go('/ask'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          HudStrip(
                            icon: Icons.watch_outlined,
                            title: device == null
                                ? 'No Vytal connected'
                                : device.displayName,
                            subtitle: device == null
                                ? 'Connect a ring to light live metrics'
                                : '${connection.state.label}'
                                    '${device.isDemo ? ' · Demo' : ''}'
                                    '${health.battery.value != null ? ' · ${health.battery.value}%' : ''}',
                            trailing: health.battery.hasValue
                                ? IconButton(
                                    tooltip: 'Battery',
                                    onPressed: () => context.push('/battery'),
                                    icon: const Icon(
                                      Icons.battery_charging_full_outlined,
                                      size: 18,
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Notes',
                                    onPressed: () => context.push('/notes'),
                                    icon: const Icon(
                                      Icons.note_alt_outlined,
                                      size: 18,
                                    ),
                                  ),
                            onTap: () => context.push('/devices'),
                          ),
                          const SizedBox(height: 10),
                          HudStrip(
                            icon: Icons.auto_awesome_outlined,
                            title: "Today's insight",
                            subtitle: health.readinessMessage,
                            onTap: () => context.go('/ask'),
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
