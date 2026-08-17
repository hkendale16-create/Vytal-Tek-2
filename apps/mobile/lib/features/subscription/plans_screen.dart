import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../domain/models/entitlements.dart';
import '../../subscription/product_catalog.dart';
import '../../subscription/subscription_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(subscriptionCatalogProvider);
    final current = ref.watch(entitlementServiceProvider);
    final controller = ref.read(subscriptionControllerProvider);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Plans',
      subtitle:
          'Compare tiers. Store prices replace placeholders once products are live.',
      child: Column(
        children: [
          for (final product in catalog.products) ...[
            _PlanCard(
              product: product,
              isCurrent: product.tier == current.tier,
              actionLabel: _actionLabel(current.tier, product.tier),
              onSelect: () async {
                final confirmed = await _confirmChange(
                  context,
                  from: current.tier,
                  to: product,
                );
                if (!confirmed || !context.mounted) return;
                final result = await controller.purchase(product);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.message)),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sandbox preview', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Preview Plus/Pro gates for UI review. This is not a purchase '
                  'and is never production authority.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tier in SubscriptionTier.values)
                      OutlinedButton(
                        onPressed: () async {
                          await controller.applySandboxPreview(tier);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sandbox preview: ${tier.displayLabel}',
                              ),
                            ),
                          );
                        },
                        child: Text('Preview ${tier.displayLabel}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(SubscriptionTier current, SubscriptionTier target) {
    if (current == target) return 'Current plan';
    if (target == SubscriptionTier.free) return 'Downgrade to Free';
    if (current == SubscriptionTier.free) return 'Subscribe';
    if (target.index > current.index) return 'Upgrade';
    return 'Downgrade';
  }

  Future<bool> _confirmChange(
    BuildContext context, {
    required SubscriptionTier from,
    required SubscriptionProduct to,
  }) async {
    if (from == to.tier) return false;
    final isUpgrade = to.tier.index > from.index;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUpgrade ? 'Confirm upgrade' : 'Confirm plan change'),
        content: Text(
          isUpgrade
              ? 'Upgrade from ${from.displayLabel} to ${to.displayName}.\n\n'
                  'New features activate after store confirmation and Vytal '
                  'server verification. Billing uses the platform’s official '
                  'proration — Vytal never invents a charge difference.'
              : to.tier == SubscriptionTier.free
                  ? 'Paid cancellations are managed in the App Store / Play '
                      'subscription sheet. Access continues until the period ends.'
                  : 'Change from ${from.displayLabel} to ${to.displayName}.\n\n'
                      'Downgrades follow marketplace timing. You keep current '
                      'access until the change takes effect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isUpgrade ? 'Continue' : 'Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.isCurrent,
    required this.actionLabel,
    required this.onSelect,
  });

  final SubscriptionProduct product;
  final bool isCurrent;
  final String actionLabel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      glow: product.isPopular || isCurrent,
      accent: product.isPopular ? VytalColors.teal : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.displayName,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (product.isPopular)
                const StatusPill(label: 'Popular', emphasis: true),
              if (isCurrent) ...[
                const SizedBox(width: 6),
                const StatusPill(label: 'Current', emphasis: true),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(product.tagline, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(
            [
              if (product.displayPriceLabel != null) product.displayPriceLabel!,
              if (product.periodLabel != null) product.periodLabel!,
            ].join(' · '),
            style: theme.textTheme.titleMedium?.copyWith(
              color: VytalColors.teal,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final line in product.highlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 18, color: VytalColors.teal),
                  const SizedBox(width: 8),
                  Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: isCurrent ? null : onSelect,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
