import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/entitlements.dart';
import '../../subscription/subscription_controller.dart';
import '../shared/health_ui.dart';

/// Soft lock for premium features — keeps data, offers View Plans.
class SoftPaywall extends ConsumerWidget {
  const SoftPaywall({
    super.key,
    required this.entitlementKey,
    this.compact = false,
  });

  final String entitlementKey;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(subscriptionCatalogProvider);
    final plan = catalog.requiredPlanLabel(entitlementKey);
    final service = ref.watch(entitlementServiceProvider);
    final theme = Theme.of(context);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: VytalColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  EntitlementKeys.displayName(entitlementKey),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            service.lockedMessage(entitlementKey, planLabel: plan),
            style: theme.textTheme.bodyMedium,
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              'Your data stays. Premium analysis unlocks with the plan — '
              'nothing is deleted when access ends.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => context.push('/settings/subscription/plans'),
            child: const Text('View plans'),
          ),
        ],
      ),
    );
  }
}

/// Shows [child] when entitled; otherwise [SoftPaywall].
class EntitlementGate extends ConsumerWidget {
  const EntitlementGate({
    super.key,
    required this.entitlementKey,
    required this.child,
    this.compactPaywall = false,
  });

  final String entitlementKey;
  final Widget child;
  final bool compactPaywall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUse = ref.watch(entitlementServiceProvider).canUse(entitlementKey);
    if (canUse) return child;
    return SoftPaywall(
      entitlementKey: entitlementKey,
      compact: compactPaywall,
    );
  }
}
