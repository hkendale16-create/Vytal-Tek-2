import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_mode_controller.dart';
import '../../core/theme/vytal_colors.dart';
import '../../domain/models/operating_mode.dart';
import '../../domain/models/personal_profile.dart';
import '../../state/app_session_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

/// Identity, goals, and onboarding details. Feature hubs live in More.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final profile = session.profile;
    final name = profile.displayName?.trim();

    return SectionScaffold(
      title: 'Profile',
      subtitle: 'Personal information used by Coach and workouts.',
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
          FilledButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (context) => const _EditProfileSheet(),
            ),
            child: const Text('Edit profile'),
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Personal information',
            rows: [
              ('Age range', profile.ageRange),
              (
                'Height',
                profile.heightCm == null
                    ? null
                    : '${profile.heightCm!.toStringAsFixed(0)} cm',
              ),
              (
                'Weight',
                profile.weightKg == null
                    ? null
                    : '${profile.weightKg!.toStringAsFixed(0)} kg',
              ),
              ('Typical wake', profile.typicalWakeTime),
              ('Typical bedtime', profile.typicalBedtime),
            ],
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Fitness goals',
            rows: [
              ('Goals', _join(profile.goals)),
              ('Experience', profile.fitnessExperience),
              ('Limitations', _join(profile.limitations)),
            ],
          ),
          const SizedBox(height: 12),
          _InfoPanel(
            title: 'Workout preferences',
            rows: [
              ('Preferred workouts', _join(profile.preferredWorkouts)),
              ('Equipment', _join(profile.availableEquipment)),
              (
                'Typical duration',
                profile.preferredWorkoutDurationMinutes == null
                    ? null
                    : '${profile.preferredWorkoutDurationMinutes} min',
              ),
            ],
          ),
          const SizedBox(height: 12),
          GlassPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('AI personalization'),
                  subtitle: const Text(
                    'Coach uses this profile plus today’s summary — not your full history.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/ask'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Onboarding details'),
                  subtitle: Text(
                    profile.skippedSensitiveQuestions.isEmpty
                        ? 'Answers from first launch stay on-device.'
                        : 'Skipped: ${profile.skippedSensitiveQuestions.join(', ')}',
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
                  subtitle: const Text(
                    'Labeled demo wearable only — never production',
                  ),
                  value: session.demoModeEnabled,
                  onChanged: (value) =>
                      ref.read(appSessionProvider.notifier).setDemoMode(value),
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
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
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

  String? _join(List<String> values) =>
      values.isEmpty ? null : values.join(', ');
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.rows});

  final String title;
  final List<(String, String?)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final row in rows) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 128,
                    child: Text(
                      row.$1,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2 == null || row.$2!.isEmpty ? 'Not set' : row.$2!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _duration;
  late final TextEditingController _goals;
  late final TextEditingController _equipment;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(appSessionProvider).profile;
    _name = TextEditingController(text: profile.displayName ?? '');
    _height = TextEditingController(
      text: profile.heightCm?.toStringAsFixed(0) ?? '',
    );
    _weight = TextEditingController(
      text: profile.weightKg?.toStringAsFixed(0) ?? '',
    );
    _duration = TextEditingController(
      text: profile.preferredWorkoutDurationMinutes?.toString() ?? '',
    );
    _goals = TextEditingController(text: profile.goals.join(', '));
    _equipment = TextEditingController(text: profile.availableEquipment.join(', '));
  }

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    _duration.dispose();
    _goals.dispose();
    _equipment.dispose();
    super.dispose();
  }

  List<String> _split(String raw) => raw
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final current = ref.read(appSessionProvider).profile;
    await ref.read(appSessionProvider.notifier).updateProfile(
          PersonalProfile(
            displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
            ageRange: current.ageRange,
            heightCm: double.tryParse(_height.text.trim()),
            weightKg: double.tryParse(_weight.text.trim()),
            goals: _split(_goals.text),
            fitnessExperience: current.fitnessExperience,
            preferredWorkouts: current.preferredWorkouts,
            availableEquipment: _split(_equipment.text),
            typicalWakeTime: current.typicalWakeTime,
            typicalBedtime: current.typicalBedtime,
            preferredWorkoutDurationMinutes:
                int.tryParse(_duration.text.trim()),
            limitations: current.limitations,
            skippedSensitiveQuestions: current.skippedSensitiveQuestions,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _height,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _weight,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Typical workout minutes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _goals,
              decoration: const InputDecoration(
                labelText: 'Goals (comma separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _equipment,
              decoration: const InputDecoration(
                labelText: 'Equipment (comma separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
