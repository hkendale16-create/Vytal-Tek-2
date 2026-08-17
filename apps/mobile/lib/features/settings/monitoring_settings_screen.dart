import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions/permission_catalog.dart';
import '../../core/permissions/permission_prompt.dart';
import '../../domain/models/monitoring_mode.dart';
import '../../monitoring/monitoring_controller.dart';
import '../../monitoring/monitoring_signals.dart';
import '../../state/app_session_controller.dart';
import '../shared/ui_primitives.dart';

class MonitoringSettingsScreen extends ConsumerWidget {
  const MonitoringSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final runtime = ref.watch(monitoringControllerProvider);
    final monitoring = ref.read(monitoringControllerProvider.notifier);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Monitoring',
      subtitle:
          'Requires OS permission and can use more battery. You can turn it off anytime.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Automatic monitoring mode'),
              subtitle: const Text(
                'When on, Vytal may move between Active, Normal, and Standby. Turn off to lock your manual selection.',
              ),
              value: session.automaticMonitoringEnabled,
              onChanged: (value) => monitoring.setAutomatic(value),
            ),
          ),
          const SizedBox(height: 12),
          Text('Current mode', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<MonitoringMode>(
            segments: [
              for (final mode in MonitoringMode.values)
                ButtonSegment(
                  value: mode,
                  label: Text(mode.label),
                ),
            ],
            selected: {runtime.mode},
            onSelectionChanged: (values) {
              monitoring.selectModeManually(values.first);
            },
          ),
          const SizedBox(height: 12),
          EmptyMetricCard(
            title: '${runtime.mode.label} · ${runtime.reason.label}',
            message:
                '${runtime.mode.description}\n\n'
                'Sensor poll: ${_formatDuration(runtime.policy.sensorPollInterval)}\n'
                'UI refresh: ${_formatDuration(runtime.policy.uiRefreshInterval)}\n'
                'Sync cadence: ${_formatDuration(runtime.policy.syncInterval)}\n'
                'Battery impact: ${runtime.policy.expectedBatteryImpact}',
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Background monitoring'),
              subtitle: Text(runtime.gate.userFacingStatus),
              value: session.backgroundMonitoringEnabled,
              onChanged: (value) async {
                if (value) {
                  await ensureVytalPermission(
                    context: context,
                    ref: ref,
                    item: PermissionCatalog.notifications,
                    headline: 'Background monitoring',
                    explanation:
                        'Background monitoring may need notification access so Vytal can keep a discreet status while the app is not open.',
                  );
                }
                monitoring.setBackgroundMonitoring(value);
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Active workout monitoring (simulate)'),
              subtitle: const Text(
                'Phase 3 signal for automatic Active mode. Real workout detection arrives with activity tracking.',
              ),
              value: runtime.signals.workoutActive,
              onChanged: (value) => monitoring.setWorkoutActive(value),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Sleep period (simulate)'),
              subtitle: const Text(
                'When automatic mode is on, sleep prefers Standby and calmer behavior.',
              ),
              value: runtime.signals.isSleeping,
              onChanged: (value) => monitoring.setSleeping(value),
            ),
          ),
          const SizedBox(height: 12),
          Text('Signal snapshot', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          EmptyMetricCard(
            title: runtime.gate.appInForeground ? 'Foreground' : 'Background',
            message: [
              'Automatic: ${runtime.signals.automaticMonitoringEnabled ? 'On' : 'Off'}',
              'Background monitoring: ${runtime.signals.backgroundMonitoringEnabled ? 'On' : 'Off'}',
              'High-frequency sampling: ${runtime.isHighFrequency ? 'Allowed' : 'Reduced'}',
              'Wearable battery: ${runtime.signals.wearableBatteryPercent?.toString() ?? 'Unavailable'}',
              'Inactivity: ${_formatDuration(runtime.signals.inactiveFor)}',
              'Eval ticks: ${runtime.tickCount}',
            ].join('\n'),
          ),
          const SizedBox(height: 12),
          Text(
            'Vytal does not run prohibited hidden background work. '
            'Platform limits always apply once a wearable SDK is connected.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours >= 1) return '${duration.inHours}h';
    if (duration.inMinutes >= 1) return '${duration.inMinutes}m';
    if (duration.inSeconds >= 1) return '${duration.inSeconds}s';
    return '${duration.inMilliseconds}ms';
  }
}
