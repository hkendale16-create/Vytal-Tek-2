import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../devices/connection/device_connection_controller.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/models/monitoring_mode.dart';
import '../../domain/models/operating_mode.dart';
import '../../domain/models/personal_profile.dart';
import '../../monitoring/monitoring_controller.dart';
import '../../monitoring/monitoring_signals.dart';
import '../../state/app_session_controller.dart';
import '../shared/ui_primitives.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final connection = ref.watch(deviceConnectionProvider);
    final monitoring = ref.watch(monitoringControllerProvider);
    final name = session.profile.displayName?.trim();
    final greeting = (name == null || name.isEmpty) ? 'Welcome' : 'Hello, $name';
    final device = connection.activeDevice ?? session.pairedDevice;

    return SectionScaffold(
      title: 'Today',
      subtitle: 'How am I doing today?',
      actions: [
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(greeting, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(label: session.operatingMode.label, emphasis: true),
              StatusPill(
                label: 'Monitoring · ${monitoring.mode.label}',
                emphasis: monitoring.mode == MonitoringMode.active,
              ),
              StatusPill(label: monitoring.reason.label),
              if (session.demoModeEnabled)
                const StatusPill(label: 'Demo mode', emphasis: true),
            ],
          ),
          const SizedBox(height: 20),
          EmptyMetricCard(
            title: 'Readiness',
            message: session.operatingMode == OperatingMode.appOnly
                ? 'No wearable readings yet. Complete your profile and workouts in App-Only Mode — readiness personalizes after pairing and baseline learning.'
                : session.baselineState.userFacingMessage,
          ),
          const SizedBox(height: 12),
          EmptyMetricCard(
            title: 'Device',
            message: device == null
                ? 'No device paired. Connect My Vytal when your wearable arrives — your goals and history stay.'
                : '${device.displayName} · ${connection.state.label}'
                    '${device.isDemo ? ' · Demo' : ''}'
                    '${connection.battery?.value != null ? ' · Battery ${connection.battery!.value}%' : ''}',
          ),
          const SizedBox(height: 12),
          EmptyMetricCard(
            title: 'Ask Vytal',
            message:
                'AI Coach foundation is ready. Insights will use your profile now and wearable context after pairing — never invented sensor values.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/devices'),
            icon: const Icon(Icons.add_link),
            label: const Text('Connect My Vytal'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings/monitoring'),
            icon: const Icon(Icons.tune),
            label: const Text('Monitoring controls'),
          ),
        ],
      ),
    );
  }
}
