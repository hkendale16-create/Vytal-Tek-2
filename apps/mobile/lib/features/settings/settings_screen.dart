import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_mode_controller.dart';
import '../../domain/models/monitoring_mode.dart';
import '../../state/app_session_controller.dart';
import '../shared/ui_primitives.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final session = ref.watch(appSessionProvider);

    return SectionScaffold(
      title: 'Settings',
      subtitle: 'Appearance, monitoring, permissions, privacy, and subscription.',
      child: Column(
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Appearance'),
                  subtitle: Text(_themeLabel(themeMode)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.phone_iphone),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (values) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setMode(values.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Monitoring'),
                  subtitle: Text(session.monitoringMode.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/monitoring'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Permissions'),
                  subtitle: const Text('Bluetooth, notifications, activity'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/permissions'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.watch_outlined),
                  title: const Text('Devices'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/devices'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Demo mode'),
              subtitle: const Text(
                'Allows explicitly labeled demo visuals only. Never presents simulated vitals as real.',
              ),
              value: session.demoModeEnabled,
              onChanged: (value) =>
                  ref.read(appSessionProvider.notifier).setDemoMode(value),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Subscription'),
              subtitle: Text(session.entitlements.statusLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/subscription'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Privacy & Data'),
              subtitle: const Text(
                'Export, deletion, and AI personalization controls are planned. Health data uses secure storage and RLS-backed backend access.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (context) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Vytal Tek does not sell health data. Export and deletion '
                      'tools ship with the backend privacy controls. Until then, '
                      'notes and routines stay on-device.',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'Follow system',
      };
}
