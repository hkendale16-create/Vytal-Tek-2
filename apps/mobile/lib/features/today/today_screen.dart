import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
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

    return CustomScrollView(
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(greeting, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                      'How am I doing today?',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill(
                          label: session.operatingMode.label,
                          emphasis: true,
                        ),
                        StatusPill(
                          label: 'Monitoring · ${monitoring.mode.label}',
                          emphasis: monitoring.mode == MonitoringMode.active,
                        ),
                        if (session.demoModeEnabled)
                          const StatusPill(label: 'Demo mode', emphasis: true),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ReadinessGauge(
                        score: health.readinessScore,
                        label: 'READINESS',
                        subtitle: health.readinessScore == null
                            ? null
                            : health.provenance == DataProvenance.demo
                                ? 'Demo presentation'
                                : 'Baseline learning',
                        provenance: health.readinessScore == null
                            ? null
                            : health.provenance,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      health.readinessMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        MetricHudTile(
                          title: 'Heart Rate',
                          value: health.heartRate.hasValue
                              ? '${health.heartRate.value}'
                              : null,
                          unit: 'BPM',
                          icon: Icons.favorite_outline,
                          provenance: health.heartRate.provenance,
                          emptyMessage: health.heartRate.statusLabel ??
                              health.heartRate.freshness.label,
                        ),
                        MetricHudTile(
                          title: 'Steps',
                          value: health.steps?.toString(),
                          unit: '',
                          icon: Icons.directions_walk,
                          provenance:
                              health.steps == null ? null : health.provenance,
                          emptyMessage: 'No step total yet',
                        ),
                        MetricHudTile(
                          title: 'SpO₂',
                          value: health.spo2.hasValue
                              ? '${health.spo2.value}'
                              : null,
                          unit: '%',
                          icon: Icons.water_drop_outlined,
                          provenance: health.spo2.provenance,
                          emptyMessage:
                              health.spo2.statusLabel ?? health.spo2.freshness.label,
                        ),
                        MetricHudTile(
                          title: 'HRV',
                          value:
                              health.hrv.hasValue ? '${health.hrv.value}' : null,
                          unit: 'ms',
                          icon: Icons.graphic_eq,
                          provenance: health.hrv.provenance,
                          emptyMessage:
                              health.hrv.statusLabel ?? health.hrv.freshness.label,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Device', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            device == null
                                ? 'No device paired. Connect My Vytal when your wearable arrives.'
                                : '${device.displayName} · ${connection.state.label}'
                                    '${device.isDemo ? ' · Demo' : ''}'
                                    '${health.battery.value != null ? ' · Battery ${health.battery.value}%' : ''}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => context.push('/devices'),
                                  icon: const Icon(Icons.add_link),
                                  label: Text(
                                    device == null ? 'Connect My Vytal' : 'Devices',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => context.push('/body'),
                                child: const Text('Live Body'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: VytalColors.teal),
                              const SizedBox(width: 8),
                              Text('Coach Vital', style: theme.textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            session.operatingMode == OperatingMode.appOnly
                                ? 'Ask Vytal using your profile now. Wearable context unlocks after pairing — never invented sensors.'
                                : 'Insights use verified profile + wearable summaries only.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => context.push('/ask'),
                              child: const Text('Open Coach Vital'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
