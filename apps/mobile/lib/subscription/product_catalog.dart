import '../domain/models/entitlements.dart';

/// Configurable product / plan definition.
///
/// Marketing names and display prices are placeholders until approved.
/// Feature access is always keyed through [EntitlementKeys], never plan names.
class SubscriptionProduct {
  const SubscriptionProduct({
    required this.id,
    required this.tier,
    required this.displayName,
    required this.tagline,
    required this.entitlements,
    required this.highlights,
    this.displayPriceLabel,
    this.periodLabel,
    this.isPopular = false,
  });

  final String id;
  final SubscriptionTier tier;
  final String displayName;
  final String tagline;
  final Set<String> entitlements;
  final List<String> highlights;

  /// Placeholder only — real localized price comes from the store (Phase B/C).
  final String? displayPriceLabel;
  final String? periodLabel;
  final bool isPopular;

  bool includes(String key) => entitlements.contains(key);
}

/// Central product catalog — single source for Free / Plus / Pro maps.
class SubscriptionCatalog {
  const SubscriptionCatalog(this.products);

  final List<SubscriptionProduct> products;

  SubscriptionProduct productForTier(SubscriptionTier tier) =>
      products.firstWhere((p) => p.tier == tier);

  SubscriptionProduct? byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  SubscriptionTier? lowestTierFor(String entitlementKey) {
    for (final tier in SubscriptionTier.values) {
      if (productForTier(tier).includes(entitlementKey)) return tier;
    }
    return null;
  }

  String requiredPlanLabel(String entitlementKey) {
    final tier = lowestTierFor(entitlementKey);
    return tier?.displayLabel ?? 'a higher plan';
  }

  /// Default configurable catalog (names/prices not final).
  static final SubscriptionCatalog standard = SubscriptionCatalog([
    const SubscriptionProduct(
      id: 'vytal.core.free',
      tier: SubscriptionTier.free,
      displayName: 'Free / Core',
      tagline: 'Start strong before hardware arrives.',
      displayPriceLabel: '\$0',
      periodLabel: 'forever',
      entitlements: {
        EntitlementKeys.aiBasic,
        EntitlementKeys.analyticsBasic,
        EntitlementKeys.workoutsCustom,
      },
      highlights: [
        'Basic profile & App-Only tools',
        'Custom workout routines',
        'Timers & stopwatch',
        'Coach Vital (basic)',
        'Basic insights',
      ],
    ),
    const SubscriptionProduct(
      id: 'vytal.plus.monthly',
      tier: SubscriptionTier.plus,
      displayName: 'Vytal Plus',
      tagline: 'Deeper trends and recovery guidance.',
      displayPriceLabel: 'Coming soon',
      periodLabel: 'per month',
      isPopular: true,
      entitlements: {
        EntitlementKeys.aiBasic,
        EntitlementKeys.analyticsBasic,
        EntitlementKeys.analyticsAdvanced,
        EntitlementKeys.recoveryAdvanced,
        EntitlementKeys.sleepAdvanced,
        EntitlementKeys.workoutsCustom,
        EntitlementKeys.workoutsAiGenerated,
        EntitlementKeys.historyExtended,
      },
      highlights: [
        'Everything in Free',
        'Advanced analytics & recovery',
        'Expanded sleep insights',
        'AI-generated workouts',
        'Extended history',
      ],
    ),
    const SubscriptionProduct(
      id: 'vytal.pro.monthly',
      tier: SubscriptionTier.pro,
      displayName: 'Vytal Pro',
      tagline: 'Full adaptive coaching and digital-body depth.',
      displayPriceLabel: 'Coming soon',
      periodLabel: 'per month',
      entitlements: {
        EntitlementKeys.aiBasic,
        EntitlementKeys.aiAdvanced,
        EntitlementKeys.analyticsBasic,
        EntitlementKeys.analyticsAdvanced,
        EntitlementKeys.recoveryAdvanced,
        EntitlementKeys.sleepAdvanced,
        EntitlementKeys.digitalBodyAdvanced,
        EntitlementKeys.workoutsCustom,
        EntitlementKeys.workoutsAiGenerated,
        EntitlementKeys.historyExtended,
      },
      highlights: [
        'Everything in Plus',
        'Adaptive AI Coach',
        'Digital-body insights',
        'Intelligent planning',
        'Deeper personalization',
      ],
    ),
  ]);
}
