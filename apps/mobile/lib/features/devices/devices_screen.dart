import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/devices/wearable_device.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/models/monitoring_mode.dart';
import '../../domain/models/operating_mode.dart';
import '../../domain/models/personal_profile.dart';
import '../../state/app_session_controller.dart';
import '../shared/ui_primitives.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final device = session.pairedDevice;

    return SectionScaffold(
      title: 'Devices',
      subtitle: 'Pairing architecture is ready. QRing SDK integration is Phase 2.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyMetricCard(
            title: device?.displayName ?? 'No device connected',
            message: device == null
                ? 'Operating mode: ${session.operatingMode.label}. Pairing will not reset your account, goals, or history.'
                : 'Model: ${device.model ?? 'Unknown'}\n'
                    'Connection: ${session.connectionState.label}\n'
                    'Monitoring: ${session.monitoringMode.label}\n'
                    'Baseline: ${session.baselineState.userFacingMessage}',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              // Phase 1: soft-link placeholder only — does not claim SDK connectivity.
              await ref.read(appSessionProvider.notifier).markDevicePaired(
                    WearableDeviceInfo(
                      id: const Uuid().v4(),
                      displayName: 'Vytal Device (pending SDK)',
                      kind: VytalDeviceKind.smartRing,
                      model: 'Awaiting QRing adapter',
                    ),
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Connected Mode enabled for architecture testing. '
                      'Real Bluetooth pairing requires the QRing SDK.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Connect My Vytal (architecture stub)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: device == null
                ? null
                : () => ref
                    .read(appSessionProvider.notifier)
                    .disconnectDevice(remove: true),
            child: const Text('Remove device'),
          ),
          const SizedBox(height: 16),
          Text(
            'Future multi-device support uses WearableDevice adapters and '
            'DeviceCapabilities flags. Unsupported metrics stay hidden.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
