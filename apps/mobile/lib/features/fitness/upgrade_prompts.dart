import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/entitlements.dart';
import '../../subscription/subscription_controller.dart';
import '../shared/health_ui.dart';

/// Contextual soft upgrade — Start Trial / View Plans / Not Now.
class ContextualUpgradeSheet extends ConsumerWidget {
  const ContextualUpgradeSheet({
    super.key,
    required this.title,
    required this.bullets,
    this.entitlementHint,
  });

  final String title;
  final List<String> bullets;
  final String? entitlementHint;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> bullets,
    String? entitlementHint,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extras = context.vytalExtras;
    final catalog = ref.watch(subscriptionCatalogProvider);
    final pro = catalog.productForTier(SubscriptionTier.pro);

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
            child: const Text('Start Trial'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/settings/subscription/plans');
            },
            child: const Text('View Plans'),
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

const _deviceFunnelDismissedKey = 'vytal.device_funnel.dismissed.v1';

/// Soft wearable funnel — exploratory, not aggressive.
class DeviceFunnelCard extends ConsumerStatefulWidget {
  const DeviceFunnelCard({super.key});

  @override
  ConsumerState<DeviceFunnelCard> createState() => _DeviceFunnelCardState();
}

class _DeviceFunnelCardState extends ConsumerState<DeviceFunnelCard> {
  var _dismissed = false;
  var _loaded = false;

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
    if (!_loaded || _dismissed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final extras = context.vytalExtras;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'GO DEEPER',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6,
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
          Text(
            'A wearable can add body-response context around your training — '
            'recovery signals, overnight patterns, and live session feedback. '
            'App-only tracking stays fully useful either way.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/devices'),
            child: const Text('Explore Devices'),
          ),
        ],
      ),
    );
  }
}
