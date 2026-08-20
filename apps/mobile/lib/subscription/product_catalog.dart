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

/// Central product catalog — single source for Free / Plus / Pro / Complete.
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
      final match = products.where((p) => p.tier == tier);
      if (match.isEmpty) continue;
      if (match.first.includes(entitlementKey)) return tier;
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
      displayName: 'Vytal Free',
      tagline: 'A real fitness hub — wearable optional.',
      displayPriceLabel: '\$0',
      periodLabel: 'forever',
      entitlements: {
        EntitlementKeys.aiBasic,
        EntitlementKeys.analyticsBasic,
        EntitlementKeys.workoutsCustom,
        EntitlementKeys.calendarBasic,
        EntitlementKeys.plansBasic,
        EntitlementKeys.progressBasic,
        EntitlementKeys.gymsNearby,
        EntitlementKeys.exercisesLibrary,
      },
      highlights: [
        'Workout logging & Quick Start',
        'Basic fitness calendar',
        'Exercise library & Gyms Near Me',
        'Basic progress & PRs',
        'Timers & Coach Vital (basic)',
        'Bluetooth device connection',
      ],
    ),
    const SubscriptionProduct(
      id: 'vytal.plus.monthly',
      tier: SubscriptionTier.plus,
      displayName: 'Vytal Plus',
      tagline: 'Deeper trends and recovery guidance.',
      displayPriceLabel: 'Coming soon',
      periodLabel: 'per month',
      entitlements: {
        EntitlementKeys.aiBasic,
        EntitlementKeys.analyticsBasic,
        EntitlementKeys.analyticsAdvanced,
        EntitlementKeys.recoveryAdvanced,
        EntitlementKeys.sleepAdvanced,
        EntitlementKeys.workoutsCustom,
        EntitlementKeys.workoutsAiGenerated,
        EntitlementKeys.historyExtended,
        EntitlementKeys.calendarBasic,
        EntitlementKeys.calendarAdvanced,
        EntitlementKeys.plansBasic,
        EntitlementKeys.plansAdvanced,
        EntitlementKeys.progressBasic,
        EntitlementKeys.progressAdvanced,
        EntitlementKeys.gymsNearby,
        EntitlementKeys.exercisesLibrary,
      },
      highlights: [
        'Everything in Free',
        'Advanced analytics & recovery',
        'Expanded sleep insights',
        'AI-generated workouts',
        'Advanced calendar & plans',
      ],
    ),
    const SubscriptionProduct(
      id: 'vytal.pro.monthly',
      tier: SubscriptionTier.pro,
      displayName: 'Vytal Pro',
      tagline: 'AI personalization and adaptive training depth.',
      displayPriceLabel: 'Coming soon',
      periodLabel: 'per month',
      isPopular: true,
      entitlements: {
        EntitlementKeys.aiBasic,
        EntitlementKeys.aiAdvanced,
        EntitlementKeys.aiWorkoutBuilder,
        EntitlementKeys.analyticsBasic,
        EntitlementKeys.analyticsAdvanced,
        EntitlementKeys.recoveryAdvanced,
        EntitlementKeys.sleepAdvanced,
        EntitlementKeys.digitalBodyAdvanced,
        EntitlementKeys.workoutsCustom,
        EntitlementKeys.workoutsAiGenerated,
        EntitlementKeys.historyExtended,
        EntitlementKeys.calendarBasic,
        EntitlementKeys.calendarAdvanced,
        EntitlementKeys.plansBasic,
        EntitlementKeys.plansAdvanced,
        EntitlementKeys.progressBasic,
        EntitlementKeys.progressAdvanced,
        EntitlementKeys.gymsNearby,
        EntitlementKeys.exercisesLibrary,
      },
      highlights: [
        'Everything in Plus',
        'AI Workout Builder',
        'Adaptive AI Coach',
        '3D muscle history',
        'Advanced progress analytics',
        'Unlimited custom programs',
      ],
    ),
    const SubscriptionProduct(
      id: 'vytal.complete.monthly',
      tier: SubscriptionTier.complete,
      displayName: 'Vytal Complete',
      tagline: 'Vytal Pro + full device experience packaging.',
      displayPriceLabel: 'Coming soon',
      periodLabel: 'per month',
      entitlements: {
        EntitlementKeys.aiBasic,
        EntitlementKeys.aiAdvanced,
        EntitlementKeys.aiWorkoutBuilder,
        EntitlementKeys.analyticsBasic,
        EntitlementKeys.analyticsAdvanced,
        EntitlementKeys.recoveryAdvanced,
        EntitlementKeys.sleepAdvanced,
        EntitlementKeys.digitalBodyAdvanced,
        EntitlementKeys.workoutsCustom,
        EntitlementKeys.workoutsAiGenerated,
        EntitlementKeys.historyExtended,
        EntitlementKeys.calendarBasic,
        EntitlementKeys.calendarAdvanced,
        EntitlementKeys.plansBasic,
        EntitlementKeys.plansAdvanced,
        EntitlementKeys.progressBasic,
        EntitlementKeys.progressAdvanced,
        EntitlementKeys.gymsNearby,
        EntitlementKeys.exercisesLibrary,
      },
      highlights: [
        'Everything in Pro',
        'Device experience packaging',
        'Monthly, annual, or device-bundle options later',
        'Pricing not finalized',
      ],
    ),
  ]);
}
