import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../devices/connection/device_connection_controller.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../state/app_session_controller.dart';

/// Subtle global wearable link indicator — tap opens My Devices.
class WearableConnectionIndicator extends ConsumerWidget {
  const WearableConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(deviceConnectionProvider);
    final session = ref.watch(appSessionProvider);
    final device = connection.activeDevice ?? session.pairedDevice;
    if (device == null) return const SizedBox.shrink();

    final linked = connection.state.isLinked;
    final color = linked ? VytalColors.teal : VytalColors.darkTextMuted;
    final label = linked
        ? '${device.displayName.split(' ').first} connected'
        : '${device.displayName.split(' ').first} offline';

    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/devices'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: color,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String connectionStatusHeadline(DeviceConnectionState state) {
  return switch (state) {
    DeviceConnectionState.scanning => 'Searching for nearby wearables…',
    DeviceConnectionState.devicesFound => 'Select a device to connect',
    DeviceConnectionState.connecting => 'Connecting…',
    DeviceConnectionState.pairing => 'Pairing…',
    DeviceConnectionState.syncing => 'Synchronizing health data…',
    DeviceConnectionState.ready => 'Ready',
    DeviceConnectionState.reconnecting => 'Reconnecting…',
    DeviceConnectionState.error => 'Connection failed',
    DeviceConnectionState.disconnected => 'Disconnected',
    DeviceConnectionState.unpaired => 'No device paired',
    DeviceConnectionState.connected => 'Connected',
  };
}
