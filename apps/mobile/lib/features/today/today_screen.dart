import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          const AmbientCanvasGlow(intensity: 0.55),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                title: const Text('Home'),
                actions: [
                  IconButton(
                    tooltip: 'Body overview',
                    onPressed: () => context.push('/body'),
                    icon: const Icon(Icons.accessibility_new_outlined),
                  ),
                  IconButton(
                    tooltip: 'Coach Vital',
                    onPressed: () => context.push('/ask'),
                    icon: const Icon(Icons.auto_awesome_outlined),
                  ),
                  IconButton(
                    tooltip: 'Devices',
                    onPressed: () => context.push('/devices'),
                    icon: const Icon(Icons.watch_outlined),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                      final monitoringCaption = session.automaticMonitoringEnabled
                          ? 'Monitoring · Automatic — ${monitoring.mode.label}'
                          : 'Monitoring · ${monitoring.mode.label}';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(greeting, style: theme.textTheme.headlineMedium),
                          const SizedBox(height: 4),
                          Text(
                            'How am I doing today?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: extras.textMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
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
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 340,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Center(
                                  child: FloatingHud(
                                    amplitude: 4,
                                    child: ReadinessGauge(
                                      score: health.readinessScore,
                                      size: 196,
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
                                Positioned(
                                  left: 0,
                                  top: 8,
                                  child: FloatingHud(
                                    delay: const Duration(milliseconds: 180),
                                    child: SizedBox(
                                      width: 128,
                                      child: MetricHudTile(
                                        compact: true,
                                        title: 'Heart Rate',
                                        value: health.heartRate.hasValue
                                            ? '${health.heartRate.value}'
                                            : null,
                                        unit: 'BPM',
                                        icon: Icons.favorite_outline,
                                        provenance: health.heartRate.provenance,
                                        emptyMessage:
                                            health.heartRate.statusLabel ??
                                                health.heartRate.freshness.label,
                                        onTap: () => context.push(
                                          '/vitals/${HealthMetricKeys.heartRate}',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 28,
                                  child: FloatingHud(
                                    delay: const Duration(milliseconds: 420),
                                    child: SizedBox(
                                      width: 128,
                                      child: MetricHudTile(
                                        compact: true,
                                        title: 'SpO₂',
                                        value: health.spo2.hasValue
                                            ? '${health.spo2.value}'
                                            : null,
                                        unit: '%',
                                        icon: Icons.water_drop_outlined,
                                        provenance: health.spo2.provenance,
                                        emptyMessage: health.spo2.statusLabel ??
                                            health.spo2.freshness.label,
                                        onTap: () => context.push(
                                          '/vitals/${HealthMetricKeys.spo2}',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  bottom: 4,
                                  child: FloatingHud(
                                    delay: const Duration(milliseconds: 640),
                                    child: SizedBox(
                                      width: 128,
                                      child: MetricHudTile(
                                        compact: true,
                                        title: 'Steps',
                                        value: health.steps?.toString(),
                                        unit: '',
                                        icon: Icons.directions_walk,
                                        provenance: health.steps == null
                                            ? null
                                            : health.provenance,
                                        emptyMessage: 'No step total yet',
                                        onTap: () => context.push(
                                          '/vitals/${HealthMetricKeys.steps}',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 16,
                                  child: FloatingHud(
                                    delay: const Duration(milliseconds: 880),
                                    child: SizedBox(
                                      width: 128,
                                      child: MetricHudTile(
                                        compact: true,
                                        title: 'HRV',
                                        value: health.hrv.hasValue
                                            ? '${health.hrv.value}'
                                            : null,
                                        unit: 'ms',
                                        icon: Icons.graphic_eq,
                                        provenance: health.hrv.provenance,
                                        emptyMessage: health.hrv.statusLabel ??
                                            health.hrv.freshness.label,
                                        onTap: () => context.push(
                                          '/vitals/${HealthMetricKeys.hrv}',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            health.readinessMessage,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: extras.textMuted,
                            ),
                          ),
                          const SizedBox(height: 20),
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
                                onTap: () => context.push('/vitals'),
                              ),
                              HudAction(
                                icon: Icons.timer_outlined,
                                label: 'Timer',
                                onTap: () => context.push('/timers/countdown'),
                              ),
                              HudAction(
                                icon: Icons.auto_awesome_outlined,
                                label: 'Coach',
                                onTap: () => context.push('/ask'),
                              ),
                              HudAction(
                                icon: Icons.note_alt_outlined,
                                label: 'Note',
                                onTap: () => context.push('/notes'),
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
                                    tooltip: 'Live Body',
                                    onPressed: () => context.push('/body'),
                                    icon: const Icon(
                                      Icons.accessibility_new_outlined,
                                      size: 18,
                                    ),
                                  ),
                            onTap: () => context.push('/devices'),
                          ),
                          const SizedBox(height: 10),
                          HudStrip(
                            icon: Icons.auto_awesome_outlined,
                            title: 'Coach Vital',
                            subtitle: session.operatingMode ==
                                    OperatingMode.appOnly
                                ? 'Ask using your profile. Wearable context after pairing.'
                                : 'Insights use verified profile + wearable summaries.',
                            onTap: () => context.push('/ask'),
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
