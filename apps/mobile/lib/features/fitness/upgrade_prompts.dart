import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../analytics/conversion_analytics.dart';
import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/entitlements.dart';
import '../../subscription/monetization.dart';
import '../../subscription/subscription_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

/// Contextual soft upgrade — Start Trial / View Plans / Not Now.
///
/// Never shown on every launch — only at intentional Pro feature moments.
class ContextualUpgradeSheet extends ConsumerWidget {
  const ContextualUpgradeSheet({
    super.key,
    required this.title,
    required this.bullets,
    this.entitlementHint,
    this.entitlementKey,
    this.primaryLabel = 'Try Vytal Pro',
  });

  final String title;
  final List<String> bullets;
  final String? entitlementHint;
  final String? entitlementKey;
  final String primaryLabel;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> bullets,
    String? entitlementHint,
    String? entitlementKey,
    String primaryLabel = 'Try Vytal Pro',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ContextualUpgradeSheet(
          title: title,
          bullets: bullets,
          entitlementHint: entitlementHint,
          entitlementKey: entitlementKey,
          primaryLabel: primaryLabel,
        ),
      ),
    );
  }

  /// Canonical AI Workout Builder upgrade moment.
  static Future<void> showAiBuilder(BuildContext context) {
    return show(
      context,
      title: 'Build a plan around you',
      entitlementKey: EntitlementKeys.aiWorkoutBuilder,
      entitlementHint: 'Vytal Pro · helps you train smarter',
      primaryLabel: 'Try Vytal Pro',
      bullets: const [
        'Goals and preferred session length',
        'Your schedule and training days',
        'Available equipment (home or gym)',
        'Workout history you have already built',
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final catalog = ref.watch(subscriptionCatalogProvider);
    final pro = catalog.productForTier(SubscriptionTier.pro);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversionAnalyticsProvider).track(
            ConversionEvents.upgradeViewed,
            properties: {
              'surface': 'contextual_sheet',
              if (entitlementKey != null) 'feature': entitlementKey,
            },
          );
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: extras.elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: extras.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: extras.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleLarge),
          if (entitlementHint != null) ...[
            const SizedBox(height: 6),
            Text(
              entitlementHint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: extras.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Vytal Pro can create training programs around your:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          for (final bullet in bullets) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: VytalColors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(bullet, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final result =
                  await ref.read(subscriptionControllerProvider).purchase(pro);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message)),
              );
            },
            child: Text(primaryLabel),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/settings/subscription/plans');
            },
            child: const Text('See What’s Included'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
        ],
      ),
    );
  }
}

/// Visible Pro preview — Free users see what advanced unlocks (not hidden).
class ProPreviewCard extends ConsumerWidget {
  const ProPreviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.previewLabel,
    this.entitlementKey = EntitlementKeys.progressAdvanced,
  });

  final String title;
  final String subtitle;
  final String previewLabel;
  final String entitlementKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monetization = ref.watch(monetizationProvider);
    if (!monetization.showProPreviews) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final extras = context.vytalExtras;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              const StatusPill(label: 'PRO', emphasis: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: extras.textMuted),
          ),
          const SizedBox(height: 12),
          Container(
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: extras.border),
              gradient: LinearGradient(
                colors: [
                  VytalColors.teal.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
            child: Text(
              previewLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: extras.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              ref.read(conversionAnalyticsProvider).track(
                    ConversionEvents.proFeatureViewed,
                    properties: {'feature': entitlementKey},
                  );
              ContextualUpgradeSheet.show(
                context,
                title: title,
                entitlementKey: entitlementKey,
                entitlementHint: 'Vytal Pro · ${monetization.experience.principle}',
                bullets: const [
                  'Longer trends and comparisons',
                  'Deeper volume and progression insights',
                  'Smarter recommendations from your history',
                ],
              );
            },
            child: const Text('See What’s Included'),
          ),
        ],
      ),
    );
  }
}

const _deviceFunnelDismissedKey = 'vytal.device_funnel.dismissed.v1';
const _deviceFunnelMinWorkouts = 12;

/// Soft wearable funnel — only after meaningful history; not repeated.
class DeviceFunnelCard extends ConsumerStatefulWidget {
  const DeviceFunnelCard({
    super.key,
    this.completedWorkouts = 0,
    this.minWorkouts = _deviceFunnelMinWorkouts,
  });

  final int completedWorkouts;
  final int minWorkouts;

  @override
  ConsumerState<DeviceFunnelCard> createState() => _DeviceFunnelCardState();
}

class _DeviceFunnelCardState extends ConsumerState<DeviceFunnelCard> {
  var _dismissed = false;
  var _loaded = false;
  var _tracked = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed = prefs.getBool(_deviceFunnelDismissedKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deviceFunnelDismissedKey, true);
    if (!mounted) return;
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final monetization = ref.watch(monetizationProvider);
    if (!_loaded ||
        _dismissed ||
        !monetization.mayPromptDeviceExplore ||
        widget.completedWorkouts < widget.minWorkouts) {
      return const SizedBox.shrink();
    }
    if (!_tracked) {
      _tracked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(conversionAnalyticsProvider).track(
              ConversionEvents.deviceExploreViewed,
              properties: {'workouts': widget.completedWorkouts},
            );
      });
    }

    final theme = Theme.of(context);
    final extras = context.vytalExtras;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'YOU’RE BUILDING A TRAINING HISTORY',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: VytalColors.teal,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                onPressed: _dismiss,
                icon: Icon(Icons.close, size: 18, color: extras.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You’ve completed ${widget.completedWorkouts} workouts with Vytal. '
            'Add a Vytal wearable to capture supported body metrics alongside '
            'your training.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              ref.read(conversionAnalyticsProvider).track(
                    ConversionEvents.deviceConnectStarted,
                    properties: {'source': 'device_funnel_card'},
                  );
              context.push('/devices');
            },
            child: const Text('Explore Vytal Device'),
          ),
          TextButton(
            onPressed: _dismiss,
            child: const Text('Not Now'),
          ),
        ],
      ),
    );
  }
}

/// Ecosystem principle strip for subscription / plans screens.
class MonetizationPrincipleStrip extends StatelessWidget {
  const MonetizationPrincipleStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = const [
      ('Vytal Free', 'Helps you train.'),
      ('Vytal Pro', 'Helps you train smarter.'),
      ('Vytal Device', 'Helps Vytal understand how your body responds.'),
      ('Vytal Complete', 'Training + AI + wearable personalization.'),
    ];
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Text(rows[i].$1, style: theme.textTheme.titleSmall),
            Text(rows[i].$2, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
