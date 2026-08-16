/// Entitlement keys — screens ask these, not plan name strings.
abstract final class EntitlementKeys {
  static const aiBasic = 'ai.basic';
  static const aiAdvanced = 'ai.advanced';
  static const analyticsBasic = 'analytics.basic';
  static const analyticsAdvanced = 'analytics.advanced';
  static const recoveryAdvanced = 'recovery.advanced';
  static const sleepAdvanced = 'sleep.advanced';
  static const digitalBodyAdvanced = 'digital_body.advanced';
  static const workoutsCustom = 'workouts.custom';
  static const workoutsAiGenerated = 'workouts.ai_generated';
  static const historyExtended = 'history.extended';
}

/// Tier ids are configurable; do not hardcode marketing names in feature checks.
enum SubscriptionTier {
  free,
  plus,
  pro,
}

/// Placeholder entitlement map for Phase 1 — server verification comes later.
class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.tier,
    required this.enabled,
    this.expiresAt,
    this.lastVerifiedAt,
  });

  final SubscriptionTier tier;
  final Set<String> enabled;
  final DateTime? expiresAt;
  final DateTime? lastVerifiedAt;

  bool canUse(String key) => enabled.contains(key);

  static const freeDefaults = EntitlementSnapshot(
    tier: SubscriptionTier.free,
    enabled: {
      EntitlementKeys.aiBasic,
      EntitlementKeys.analyticsBasic,
      EntitlementKeys.workoutsCustom,
    },
  );
}
