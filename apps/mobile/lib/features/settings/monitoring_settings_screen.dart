import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/monitoring_mode.dart';
import '../../state/app_session_controller.dart';
import '../shared/ui_primitives.dart';

class MonitoringSettingsScreen extends ConsumerWidget {
  const MonitoringSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final controller = ref.read(appSessionProvider.notifier);

    return SectionScaffold(
      title: 'Monitoring',
      subtitle:
          'Background monitoring requires explicit OS permissions and can increase battery use.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Automatic monitoring mode'),
              subtitle: const Text(
                'When on, Vytal may move between Active, Normal, and Standby. Manual selection still works.',
              ),
              value: session.automaticMonitoringEnabled,
              onChanged: controller.setAutomaticMonitoring,
            ),
          ),
          const SizedBox(height: 12),
          Text('Current mode', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<MonitoringMode>(
            segments: [
              for (final mode in MonitoringMode.values)
                ButtonSegment(
                  value: mode,
                  label: Text(mode.label),
                ),
            ],
            selected: {session.monitoringMode},
            onSelectionChanged: (values) {
              controller.setMonitoringMode(values.first);
            },
          ),
          const SizedBox(height: 12),
          EmptyMetricCard(
            title: session.monitoringMode.label,
            message: session.monitoringMode.description,
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Background monitoring'),
              subtitle: const Text(
                'Off by default. Enable only after understanding battery and Bluetooth impact. Platform limits always apply.',
              ),
              value: session.backgroundMonitoringEnabled,
              onChanged: controller.setBackgroundMonitoring,
            ),
          ),
        ],
      ),
    );
  }
}
