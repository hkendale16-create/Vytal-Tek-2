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

  static const all = <String>{
    aiBasic,
    aiAdvanced,
    analyticsBasic,
    analyticsAdvanced,
    recoveryAdvanced,
    sleepAdvanced,
    digitalBodyAdvanced,
    workoutsCustom,
    workoutsAiGenerated,
    historyExtended,
  };

  static String displayName(String key) => switch (key) {
        aiBasic => 'Coach Vital (basic)',
        aiAdvanced => 'Adaptive AI Coach',
        analyticsBasic => 'Basic insights',
        analyticsAdvanced => 'Advanced analytics',
        recoveryAdvanced => 'Advanced recovery',
        sleepAdvanced => 'Advanced sleep insights',
        digitalBodyAdvanced => 'Digital body insights',
        workoutsCustom => 'Custom workouts',
        workoutsAiGenerated => 'AI-generated workouts',
        historyExtended => 'Extended history',
        _ => key,
      };
}

/// Tier ids are configurable; do not hardcode marketing names in feature checks.
enum SubscriptionTier {
  free,
  plus,
  pro,
}

extension SubscriptionTierX on SubscriptionTier {
  String get id => name;

  /// Configurable display labels — not final marketing copy.
  String get displayLabel => switch (this) {
        SubscriptionTier.free => 'Free / Core',
        SubscriptionTier.plus => 'Vytal Plus',
        SubscriptionTier.pro => 'Vytal Pro',
      };
}

/// Marketplace-aligned subscription lifecycle states.
enum SubscriptionLifecycle {
  none,
  active,
  canceledActive,
  gracePeriod,
  billingRetry,
  paused,
  expired,
  revoked,
}

extension SubscriptionLifecycleX on SubscriptionLifecycle {
  String get label => switch (this) {
        SubscriptionLifecycle.none => 'No paid plan',
        SubscriptionLifecycle.active => 'Active',
        SubscriptionLifecycle.canceledActive => 'Canceled — active until period end',
        SubscriptionLifecycle.gracePeriod => 'Grace period',
        SubscriptionLifecycle.billingRetry => 'Billing retry',
        SubscriptionLifecycle.paused => 'Paused',
        SubscriptionLifecycle.expired => 'Expired',
        SubscriptionLifecycle.revoked => 'Revoked',
      };

  /// Whether premium entitlements should remain unlocked.
  bool get grantsAccess => switch (this) {
        SubscriptionLifecycle.active ||
        SubscriptionLifecycle.canceledActive ||
        SubscriptionLifecycle.gracePeriod ||
        SubscriptionLifecycle.billingRetry =>
          true,
        SubscriptionLifecycle.none ||
        SubscriptionLifecycle.paused ||
        SubscriptionLifecycle.expired ||
        SubscriptionLifecycle.revoked =>
          false,
      };
}

/// Snapshot of verified (or free-default) entitlements.
///
/// Client-side flags are never authoritative for paid access. Server + store
/// notifications become source of truth in Subscription Phase D.
class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.tier,
    required this.enabled,
    required this.lifecycle,
    this.productId,
    this.expiresAt,
    this.renewsAt,
    this.lastVerifiedAt,
    this.willRenew = false,
    this.verificationSource = EntitlementVerificationSource.localFreeDefaults,
  });

  final SubscriptionTier tier;
  final Set<String> enabled;
  final SubscriptionLifecycle lifecycle;
  final String? productId;
  final DateTime? expiresAt;
  final DateTime? renewsAt;
  final DateTime? lastVerifiedAt;
  final bool willRenew;
  final EntitlementVerificationSource verificationSource;

  bool canUse(String key) => enabled.contains(key);

  bool get isPaidTier => tier != SubscriptionTier.free;

  bool get isSubscribed =>
      isPaidTier && lifecycle.grantsAccess;

  String get statusLabel {
    if (tier == SubscriptionTier.free) return 'Free plan';
    return '${tier.displayLabel} · ${lifecycle.label}';
  }

  EntitlementSnapshot copyWith({
    SubscriptionTier? tier,
    Set<String>? enabled,
    SubscriptionLifecycle? lifecycle,
    String? productId,
    DateTime? expiresAt,
    DateTime? renewsAt,
    DateTime? lastVerifiedAt,
    bool? willRenew,
    EntitlementVerificationSource? verificationSource,
    bool clearProductId = false,
    bool clearExpiresAt = false,
    bool clearRenewsAt = false,
  }) {
    return EntitlementSnapshot(
      tier: tier ?? this.tier,
      enabled: enabled ?? this.enabled,
      lifecycle: lifecycle ?? this.lifecycle,
      productId: clearProductId ? null : (productId ?? this.productId),
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      renewsAt: clearRenewsAt ? null : (renewsAt ?? this.renewsAt),
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      willRenew: willRenew ?? this.willRenew,
      verificationSource: verificationSource ?? this.verificationSource,
    );
  }

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'enabled': enabled.toList()..sort(),
        'lifecycle': lifecycle.name,
        'productId': productId,
        'expiresAt': expiresAt?.toIso8601String(),
        'renewsAt': renewsAt?.toIso8601String(),
        'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
        'willRenew': willRenew,
        'verificationSource': verificationSource.name,
      };

  factory EntitlementSnapshot.fromJson(Map<String, dynamic> json) {
    final enabledRaw = json['enabled'];
    final enabled = enabledRaw is List
        ? enabledRaw.map((e) => e.toString()).toSet()
        : freeDefaults.enabled;
    return EntitlementSnapshot(
      tier: SubscriptionTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      enabled: enabled,
      lifecycle: SubscriptionLifecycle.values.firstWhere(
        (e) => e.name == json['lifecycle'],
        orElse: () => SubscriptionLifecycle.none,
      ),
      productId: json['productId'] as String?,
      expiresAt: _parseDate(json['expiresAt']),
      renewsAt: _parseDate(json['renewsAt']),
      lastVerifiedAt: _parseDate(json['lastVerifiedAt']),
      willRenew: json['willRenew'] as bool? ?? false,
      verificationSource: EntitlementVerificationSource.values.firstWhere(
        (e) => e.name == json['verificationSource'],
        orElse: () => EntitlementVerificationSource.localFreeDefaults,
      ),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static const freeDefaults = EntitlementSnapshot(
    tier: SubscriptionTier.free,
    enabled: {
      EntitlementKeys.aiBasic,
      EntitlementKeys.analyticsBasic,
      EntitlementKeys.workoutsCustom,
    },
    lifecycle: SubscriptionLifecycle.none,
    verificationSource: EntitlementVerificationSource.localFreeDefaults,
  );

  /// Builds a snapshot for a catalog tier. Used by catalog + tests.
  ///
  /// Does **not** grant production premium — callers must attach a verified
  /// [verificationSource] after store/server confirmation (Phase B–D).
  static EntitlementSnapshot forTier(
    SubscriptionTier tier, {
    required Set<String> enabled,
    SubscriptionLifecycle lifecycle = SubscriptionLifecycle.active,
    String? productId,
    DateTime? expiresAt,
    DateTime? renewsAt,
    bool willRenew = true,
    EntitlementVerificationSource verificationSource =
        EntitlementVerificationSource.catalogPreview,
  }) {
    if (tier == SubscriptionTier.free) {
      return freeDefaults;
    }
    return EntitlementSnapshot(
      tier: tier,
      enabled: enabled,
      lifecycle: lifecycle,
      productId: productId,
      expiresAt: expiresAt,
      renewsAt: renewsAt,
      lastVerifiedAt: DateTime.now().toUtc(),
      willRenew: willRenew,
      verificationSource: verificationSource,
    );
  }
}

enum EntitlementVerificationSource {
  /// Free defaults shipped with the client.
  localFreeDefaults,

  /// UI/catalog preview only — never treat as paid access in production.
  catalogPreview,

  /// Dev sandbox preview for UI review (explicitly labeled).
  sandboxPreview,

  /// Verified by App Store / Play + backend (Phase D).
  serverVerified,
}

extension EntitlementVerificationSourceX on EntitlementVerificationSource {
  String get label => switch (this) {
        EntitlementVerificationSource.localFreeDefaults => 'Local free defaults',
        EntitlementVerificationSource.catalogPreview => 'Catalog preview',
        EntitlementVerificationSource.sandboxPreview => 'Sandbox preview',
        EntitlementVerificationSource.serverVerified => 'Server verified',
      };

  bool get isAuthoritative => this == EntitlementVerificationSource.serverVerified;
}
