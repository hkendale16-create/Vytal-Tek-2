import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

/// Overflow menu for screens that are not bottom-nav destinations.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'More',
      subtitle: 'Recovery, sleep, analytics, and account — opened on demand.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel('Health'),
          HudStrip(
            icon: Icons.bolt_outlined,
            title: 'Recovery / Readiness',
            subtitle: 'Score, HRV, sleep, load, baseline',
            onTap: () => context.push('/recovery'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.bedtime_outlined,
            title: 'Sleep',
            subtitle: 'Score, duration, stages, overnight context',
            onTap: () => context.push('/sleep'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.insights_outlined,
            title: 'Analytics',
            subtitle: '7D / 30D / 90D / 1Y aggregated trends',
            onTap: () => context.push('/analytics'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.directions_run_outlined,
            title: 'Activity',
            subtitle: 'Rings, calories, and start workout',
            onTap: () => context.push('/activity'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.accessibility_new_outlined,
            title: 'Live Body',
            subtitle: 'Region view with floating metrics',
            onTap: () => context.push('/body'),
          ),
          const SizedBox(height: 18),
          _SectionLabel('Fitness'),
          HudStrip(
            icon: Icons.storefront_outlined,
            title: 'Marketplace',
            subtitle: 'Trainer programs · interest · checkout',
            onTap: () => context.push('/fitness/marketplace'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.fitness_center_outlined,
            title: 'Workouts',
            subtitle: 'Plans, gyms, exercises, progress',
            onTap: () => context.push('/workouts'),
          ),
          const SizedBox(height: 18),
          _SectionLabel('Notes & Reminders'),
          HudStrip(
            icon: Icons.note_alt_outlined,
            title: 'Notes',
            subtitle: 'Add, edit, search, attach to a day',
            onTap: () => context.push('/notes'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.alarm_outlined,
            title: 'Reminders',
            subtitle: 'Workout, hydrate, bedtime, charge',
            onTap: () => context.push('/reminders'),
          ),
          const SizedBox(height: 18),
          _SectionLabel('Device'),
          HudStrip(
            icon: Icons.watch_outlined,
            title: 'Devices',
            subtitle: 'Pair, sync, rename, disconnect',
            onTap: () => context.push('/devices'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.battery_charging_full_outlined,
            title: 'Battery',
            subtitle: 'Level, alerts, charging tips',
            onTap: () => context.push('/battery'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.tune,
            title: 'Monitoring',
            subtitle: 'Automatic, Active / Normal / Standby',
            onTap: () => context.push('/settings/monitoring'),
          ),
          const SizedBox(height: 18),
          _SectionLabel('Account'),
          HudStrip(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Identity, goals, workout preferences',
            onTap: () => context.push('/profile'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.workspace_premium_outlined,
            title: 'Subscription',
            subtitle: 'Plan, restore, compare',
            onTap: () => context.push('/settings/subscription'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.shield_outlined,
            title: 'Permissions',
            subtitle: 'Bluetooth, notifications, activity — one place',
            onTap: () => context.push('/settings/permissions'),
          ),
          const SizedBox(height: 8),
          HudStrip(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Appearance, monitoring, privacy, account',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
