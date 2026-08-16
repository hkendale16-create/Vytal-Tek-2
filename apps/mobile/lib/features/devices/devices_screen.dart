import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../devices/connection/device_connection_controller.dart';
import '../../devices/connection/device_connection_exception.dart';
import '../../domain/devices/device_connection_state.dart';
import '../../domain/devices/wearable_device.dart';
import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../../domain/models/monitoring_mode.dart';
import '../../domain/models/operating_mode.dart';
import '../../state/app_session_controller.dart';
import '../shared/ui_primitives.dart';

class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final _renameController = TextEditingController();

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on DeviceConnectionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.userMessage),
          action: error.canRetry
              ? SnackBarAction(
                  label: 'Retry',
                  onPressed: () => _run(action),
                )
              : null,
        ),
      );
    }
  }

  String _freshnessLabel(HealthMetricReading<int>? battery) {
    if (battery == null) return ReadingFreshness.unavailable.label;
    if (battery.provenance == DataProvenance.demo) {
      return 'Demo · ${battery.freshness.label}';
    }
    return battery.freshness.label;
  }

  String _lastSyncLabel(WearableDeviceInfo? device) {
    final at = device?.lastSyncAt;
    if (at == null) return 'Never synced';
    final local = at.toLocal();
    return 'Last synced ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final connection = ref.watch(deviceConnectionProvider);
    final device = connection.activeDevice ?? session.pairedDevice;
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Devices',
      subtitle:
          'Pair, reconnect, sync, and manage wearables. Production QRing SDK pairing arrives when vendor binaries are provided.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: session.operatingMode.label,
                emphasis: true,
              ),
              StatusPill(label: connection.state.label),
              StatusPill(label: 'Monitoring · ${session.monitoringMode.label}'),
              if (session.demoModeEnabled)
                const StatusPill(label: 'Demo mode', emphasis: true),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device?.displayName ?? 'No device connected',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (device == null)
                    Text(
                      'Operating in ${session.operatingMode.label}. '
                      'Pairing will not reset your account, goals, or history.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else ...[
                    Text(
                      [
                        'Type: ${device.kind.label}',
                        'Model: ${device.model ?? 'Unknown'}',
                        'Firmware: ${device.firmwareVersion ?? 'Unavailable'}',
                        'Adapter: ${device.adapterId}',
                        'Connection: ${connection.state.label}',
                        _lastSyncLabel(device),
                        if (device.isDemo) 'Provenance: Demo (not real hardware)',
                      ].join('\n'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      connection.battery?.hasValue == true
                          ? 'Battery ${connection.battery!.value}% · ${_freshnessLabel(connection.battery)}'
                          : 'Battery · ${_freshnessLabel(connection.battery)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: VytalColors.teal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (connection.lastError != null) ...[
            const SizedBox(height: 12),
            EmptyMetricCard(
              title: 'Connection issue',
              message: connection.lastError!.userMessage,
            ),
          ],
          const SizedBox(height: 16),
          if (device == null) ...[
            FilledButton.icon(
              onPressed: connection.isScanning
                  ? null
                  : () => _run(
                        () => ref
                            .read(deviceConnectionProvider.notifier)
                            .scanForDevices(),
                      ),
              icon: connection.isScanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(
                connection.isScanning ? 'Scanning…' : 'Scan for devices',
              ),
            ),
            if (!session.demoModeEnabled) ...[
              const SizedBox(height: 8),
              Text(
                'Without Demo mode, scanning requires the QRing SDK. '
                'Enable Demo mode in Settings to exercise the full pair → sync lifecycle with clearly labeled demo devices.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ] else ...[
            FilledButton.icon(
              onPressed: connection.isSyncing
                  ? null
                  : () => _run(
                        () async {
                          await ref
                              .read(deviceConnectionProvider.notifier)
                              .syncNow();
                        },
                      ),
              icon: const Icon(Icons.sync),
              label: Text(connection.isSyncing ? 'Syncing…' : 'Sync now'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _run(
                () => ref.read(deviceConnectionProvider.notifier).reconnect(),
              ),
              icon: const Icon(Icons.link),
              label: const Text('Reconnect'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _run(
                () => ref
                    .read(deviceConnectionProvider.notifier)
                    .disconnect(remove: false),
              ),
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                _renameController.text = device.displayName;
                final name = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Rename device'),
                      content: TextField(
                        controller: _renameController,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                        autofocus: true,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, _renameController.text),
                          child: const Text('Save'),
                        ),
                      ],
                    );
                  },
                );
                if (name != null && name.trim().isNotEmpty) {
                  await ref
                      .read(deviceConnectionProvider.notifier)
                      .renameActiveDevice(name);
                }
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Rename'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _run(
                () => ref
                    .read(deviceConnectionProvider.notifier)
                    .disconnect(remove: true),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove device'),
            ),
          ],
          if (connection.discovered.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Nearby devices', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final item in connection.discovered)
              Card(
                child: ListTile(
                  leading: Icon(
                    item.kind == VytalDeviceKind.fitnessBand
                        ? Icons.watch
                        : Icons.circle_outlined,
                    color: VytalColors.teal,
                  ),
                  title: Text(item.displayName),
                  subtitle: Text(
                    [
                      item.kind.label,
                      if (item.isDemo) 'Demo',
                      if (item.rssi != null) 'Signal ${item.rssi} dBm',
                    ].join(' · '),
                  ),
                  trailing: FilledButton(
                    onPressed: () => _run(
                      () => ref
                          .read(deviceConnectionProvider.notifier)
                          .pairDiscovered(item),
                    ),
                    child: const Text('Pair'),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'Supported metrics are driven by DeviceCapabilities. '
            'Unsupported sensors stay hidden. Demo readings are never labeled as live wearable data.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
