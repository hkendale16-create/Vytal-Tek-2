import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/entitlements.dart';
import '../../subscription/subscription_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlements = ref.watch(entitlementServiceProvider);
    final snapshot = entitlements.snapshot;
    final catalog = ref.watch(subscriptionCatalogProvider);
    final product = catalog.productForTier(snapshot.tier);
    final theme = Theme.of(context);
    final controller = ref.read(subscriptionControllerProvider);

    return SectionScaffold(
      title: 'Subscription',
      subtitle: 'Current plan, status, and included features.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            glow: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current plan', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(product.displayName, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                StatusPill(label: snapshot.statusLabel, emphasis: true),
                if (snapshot.verificationSource !=
                    EntitlementVerificationSource.localFreeDefaults) ...[
                  const SizedBox(height: 8),
                  StatusPill(
                    label: snapshot.verificationSource.label,
                    emphasis: snapshot.verificationSource ==
                        EntitlementVerificationSource.sandboxPreview,
                  ),
                ],
                if (snapshot.renewsAt != null || snapshot.expiresAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _renewalCopy(snapshot),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (entitlements.isInGraceOrRetry) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Billing needs attention. Access continues during grace / retry.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: VytalColors.caution,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Features included', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final key in product.entitlements.toList()..sort())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 18, color: VytalColors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            EntitlementKeys.displayName(key),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push('/settings/subscription/plans'),
            child: Text(
              snapshot.tier == SubscriptionTier.free
                  ? 'View plans'
                  : 'Change plan',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final result = await controller.restorePurchases();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message)),
              );
            },
            child: const Text('Restore purchases'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              final result = await controller.openManageSubscriptions();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.message)),
              );
            },
            child: const Text('Manage subscription'),
          ),
          const SizedBox(height: 20),
          Text(
            'Digital subscriptions use Apple StoreKit and Google Play Billing. '
            'Client-side flags are not authoritative — server verification '
            'arrives in Subscription Phase D.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _renewalCopy(EntitlementSnapshot snapshot) {
    if (snapshot.willRenew && snapshot.renewsAt != null) {
      return 'Renews ${_formatDate(snapshot.renewsAt!)}';
    }
    if (snapshot.expiresAt != null) {
      return 'Access ends ${_formatDate(snapshot.expiresAt!)}';
    }
    return '';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
