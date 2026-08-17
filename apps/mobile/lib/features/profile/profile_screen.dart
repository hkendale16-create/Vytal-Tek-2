import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_mode_controller.dart';
import '../../core/theme/vytal_colors.dart';
import '../../domain/models/operating_mode.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

/// Profile tab matching mockup bottom nav — settings + identity.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final name = session.profile.displayName?.trim();

    return SectionScaffold(
      title: 'Profile',
      subtitle: 'Account, appearance, and demo controls.',
      child: Column(
        children: [
          GlassPanel(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: VytalColors.teal.withValues(alpha: 0.2),
                  child: Text(
                    (name == null || name.isEmpty) ? 'V' : name[0].toUpperCase(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: VytalColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (name == null || name.isEmpty) ? 'Vytal member' : name,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        session.operatingMode.label,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: const Text('Appearance'),
                  subtitle: Text(switch (themeMode) {
                    ThemeMode.system => 'System',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  }),
                  onTap: () async {
                    final next = await showModalBottomSheet<ThemeMode>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: const Text('System'),
                              onTap: () => Navigator.pop(context, ThemeMode.system),
                            ),
                            ListTile(
                              title: const Text('Light'),
                              onTap: () => Navigator.pop(context, ThemeMode.light),
                            ),
                            ListTile(
                              title: const Text('Dark'),
                              onTap: () => Navigator.pop(context, ThemeMode.dark),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (next != null) {
                      await ref.read(themeModeProvider.notifier).setMode(next);
                    }
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.science_outlined),
                  title: const Text('Demo mode'),
                  subtitle: const Text('Labeled demo wearable only — never production'),
                  value: session.demoModeEnabled,
                  onChanged: (value) =>
                      ref.read(appSessionProvider.notifier).setDemoMode(value),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('All settings'),
                  onTap: () => context.push('/settings'),
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Subscription'),
                  subtitle: Text(session.entitlements.statusLabel),
                  onTap: () => context.push('/settings/subscription'),
                ),
                ListTile(
                  leading: const Icon(Icons.watch_outlined),
                  title: const Text('Devices'),
                  onTap: () => context.push('/devices'),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Coach Vital'),
                  onTap: () => context.push('/ask'),
                ),
                ListTile(
                  leading: const Icon(Icons.note_alt_outlined),
                  title: const Text('Notes'),
                  onTap: () => context.push('/notes'),
                ),
                ListTile(
                  leading: const Icon(Icons.alarm_outlined),
                  title: const Text('Reminders'),
                  onTap: () => context.push('/reminders'),
                ),
                ListTile(
                  leading: const Icon(Icons.accessibility_new_outlined),
                  title: const Text('Live Body'),
                  onTap: () => context.push('/body'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const BrandMark(),
          const SizedBox(height: 8),
          Text(
            'LIVE BETTER. BECOME STRONGER. EVERY DAY.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1.4,
              color: VytalColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}
