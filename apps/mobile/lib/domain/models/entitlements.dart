import 'package:flutter/foundation.dart';

/// Entitlement keys — screens ask these, not plan name strings.
abstract final class EntitlementKeys {
  static const aiBasic = 'ai.basic';
  static const aiAdvanced = 'ai.advanced';
  static const aiWorkoutBuilder = 'ai.workout_builder';
  static const analyticsBasic = 'analytics.basic';
  static const analyticsAdvanced = 'analytics.advanced';
  static const recoveryAdvanced = 'recovery.advanced';
  static const sleepAdvanced = 'sleep.advanced';
  static const digitalBodyAdvanced = 'digital_body.advanced';
  static const workoutsCustom = 'workouts.custom';
  static const workoutsAiGenerated = 'workouts.ai_generated';
  static const historyExtended = 'history.extended';
  static const calendarBasic = 'calendar.basic';
  static const calendarAdvanced = 'calendar.advanced';
  static const plansBasic = 'plans.basic';
  static const plansAdvanced = 'plans.advanced';
  static const progressBasic = 'progress.basic';
  static const progressAdvanced = 'progress.advanced';
  static const gymsNearby = 'gyms.nearby';
  static const exercisesLibrary = 'exercises.library';

  static const all = <String>{
    aiBasic,
    aiAdvanced,
    aiWorkoutBuilder,
    analyticsBasic,
    analyticsAdvanced,
    recoveryAdvanced,
    sleepAdvanced,
    digitalBodyAdvanced,
    workoutsCustom,
    workoutsAiGenerated,
    historyExtended,
    calendarBasic,
    calendarAdvanced,
    plansBasic,
    plansAdvanced,
    progressBasic,
    progressAdvanced,
    gymsNearby,
    exercisesLibrary,
  };

  static String displayName(String key) => switch (key) {
        aiBasic => 'Coach Vital (basic)',
        aiAdvanced => 'Adaptive AI Coach',
        aiWorkoutBuilder => 'AI Workout Builder',
        analyticsBasic => 'Basic insights',
        analyticsAdvanced => 'Advanced analytics',
        recoveryAdvanced => 'Advanced recovery',
        sleepAdvanced => 'Advanced sleep insights',
        digitalBodyAdvanced => 'Digital body insights',
        workoutsCustom => 'Custom workouts',
        workoutsAiGenerated => 'AI-generated workouts',
        historyExtended => 'Extended history',
        calendarBasic => 'Fitness calendar',
        calendarAdvanced => 'Advanced calendar planning',
        plansBasic => 'Workout plan library',
        plansAdvanced => 'Advanced & adaptive plans',
        progressBasic => 'Basic progress',
        progressAdvanced => 'Advanced progress analytics',
        gymsNearby => 'Gyms Near Me',
        exercisesLibrary => 'Exercise library',
        _ => key,
      };
}

/// Tier ids are configurable; do not hardcode marketing names in feature checks.
///
/// Product packaging (marketing):
/// - Free — genuinely useful device-free fitness
/// - Plus — transitional mid tier (kept for store compatibility)
/// - Pro — AI + advanced analytics / planning
/// - Complete — Pro software + device experience packaging (pricing not final)
enum SubscriptionTier {
  free,
  plus,
  pro,
  complete,
}

extension SubscriptionTierX on SubscriptionTier {
  String get id => name;

  /// Configurable display labels — not final marketing copy.
  String get displayLabel => switch (this) {
        SubscriptionTier.free => 'Vytal Free',
        SubscriptionTier.plus => 'Vytal Plus',
        SubscriptionTier.pro => 'Vytal Pro',
        SubscriptionTier.complete => 'Vytal Complete',
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

  /// Feature gate — paid keys require an authoritative verification source.
  bool canUse(String key) => EntitlementSecurity.canUse(this, key);

  bool get isPaidTier => tier != SubscriptionTier.free;

  bool get isSubscribed =>
      isPaidTier &&
      lifecycle.grantsAccess &&
      EntitlementSecurity.sourceGrantsPaidAccess(verificationSource);

  String get statusLabel {
    if (verificationSource ==
        EntitlementVerificationSource.localCacheUntrusted) {
      return 'Verifying subscription…';
    }
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

  /// Raw decode — for trusted server verifier payloads only.
  factory EntitlementSnapshot.parse(Map<String, dynamic> json) {
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

  /// Disk / SharedPreferences restore — paid access is stripped (Phase F).
  factory EntitlementSnapshot.fromJson(Map<String, dynamic> json) {
    return EntitlementSecurity.sanitizeForPersistRestore(
      EntitlementSnapshot.parse(json),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Vytal Free — genuinely useful without a wearable or paid plan.
  static const freeDefaults = EntitlementSnapshot(
    tier: SubscriptionTier.free,
    enabled: {
      EntitlementKeys.aiBasic,
      EntitlementKeys.analyticsBasic,
      EntitlementKeys.workoutsCustom,
      EntitlementKeys.calendarBasic,
      EntitlementKeys.plansBasic,
      EntitlementKeys.progressBasic,
      EntitlementKeys.gymsNearby,
      EntitlementKeys.exercisesLibrary,
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

  /// Paid claim was on disk — access stripped until restore + re-verify (Phase F).
  localCacheUntrusted,
}

extension EntitlementVerificationSourceX on EntitlementVerificationSource {
  String get label => switch (this) {
        EntitlementVerificationSource.localFreeDefaults => 'Local free defaults',
        EntitlementVerificationSource.catalogPreview => 'Catalog preview',
        EntitlementVerificationSource.sandboxPreview => 'Sandbox preview',
        EntitlementVerificationSource.serverVerified => 'Server verified',
        EntitlementVerificationSource.localCacheUntrusted =>
          'Cached — needs re-verification',
      };

  bool get isAuthoritative =>
      this == EntitlementVerificationSource.serverVerified;
}

abstract final class EntitlementSecurity {
  /// Keys that never require server verification.
  static Set<String> get freeKeys => EntitlementSnapshot.freeDefaults.enabled;

  static bool isPaidKey(String key) => !freeKeys.contains(key);

  /// Whether this source may unlock paid entitlement keys.
  static bool sourceGrantsPaidAccess(EntitlementVerificationSource source) {
    if (source.isAuthoritative) return true;
    // Debug / profile only — never in release.
    if (source == EntitlementVerificationSource.sandboxPreview) {
      return !kReleaseMode;
    }
    return false;
  }

  /// Hardened feature check used by [EntitlementSnapshot.canUse].
  static bool canUse(EntitlementSnapshot snapshot, String key) {
    if (!snapshot.enabled.contains(key)) return false;
    if (!isPaidKey(key)) return true;
    if (!snapshot.lifecycle.grantsAccess && snapshot.isPaidTier) {
      return false;
    }
    return sourceGrantsPaidAccess(snapshot.verificationSource);
  }

  /// Strip paid access from disk restores. Keeps [productId] as a restore hint.
  static EntitlementSnapshot sanitizeForPersistRestore(
    EntitlementSnapshot parsed,
  ) {
    final hasPaidKeys = parsed.enabled.any(isPaidKey);
    final claimsPaid = parsed.isPaidTier ||
        hasPaidKeys ||
        parsed.verificationSource ==
            EntitlementVerificationSource.serverVerified ||
        parsed.verificationSource ==
            EntitlementVerificationSource.sandboxPreview ||
        parsed.verificationSource ==
            EntitlementVerificationSource.catalogPreview ||
        parsed.verificationSource ==
            EntitlementVerificationSource.localCacheUntrusted;

    if (!claimsPaid) {
      // Still intersect enabled with free keys to defeat key injection.
      return parsed.copyWith(
        enabled: parsed.enabled.intersection(freeKeys),
        tier: SubscriptionTier.free,
        lifecycle: SubscriptionLifecycle.none,
        verificationSource: EntitlementVerificationSource.localFreeDefaults,
        willRenew: false,
        clearExpiresAt: true,
        clearRenewsAt: true,
      );
    }

    return EntitlementSnapshot.freeDefaults.copyWith(
      productId: parsed.productId,
      verificationSource: EntitlementVerificationSource.localCacheUntrusted,
      lastVerifiedAt: parsed.lastVerifiedAt,
    );
  }

  /// Returns null when [candidate] may be applied; otherwise a rejection reason.
  static String? assertAssignable(EntitlementSnapshot candidate) {
    final paidEnabled = candidate.enabled.where(isPaidKey).toSet();
    if (paidEnabled.isEmpty && candidate.tier == SubscriptionTier.free) {
      return null;
    }

    if (candidate.verificationSource ==
        EntitlementVerificationSource.catalogPreview) {
      return 'catalogPreview cannot grant entitlements.';
    }

    if (candidate.verificationSource ==
        EntitlementVerificationSource.localCacheUntrusted) {
      return 'localCacheUntrusted cannot grant entitlements — restore purchases.';
    }

    if (paidEnabled.isNotEmpty &&
        !sourceGrantsPaidAccess(candidate.verificationSource)) {
      return 'Paid entitlements require serverVerified'
          '${kReleaseMode ? '' : ' (or sandboxPreview in debug)'}.';
    }

    if (candidate.isPaidTier &&
        candidate.verificationSource ==
            EntitlementVerificationSource.localFreeDefaults) {
      return 'localFreeDefaults cannot claim a paid tier.';
    }

    // Reject serverVerified snapshots that somehow enable keys outside catalog
    // knowledge — still allow any subset of known keys.
    final unknown = paidEnabled.difference(EntitlementKeys.all);
    if (unknown.isNotEmpty) {
      return 'Unknown entitlement keys: ${unknown.join(', ')}';
    }

    return null;
  }

  /// True when a restorePurchases pass should be attempted after launch.
  static bool shouldAttemptRestore(EntitlementSnapshot snapshot) {
    return snapshot.verificationSource ==
            EntitlementVerificationSource.localCacheUntrusted &&
        snapshot.productId != null;
  }
}

/// Hardware / device experience is separate from software Pro entitlements.
///
/// Owning a compatible wearable unlocks capability-gated features. These are
/// not subscription keys — they depend on [DeviceCapabilities] + connection.
abstract final class DeviceExperienceFeatures {
  static const liveReadings = 'device.live_readings';
  static const automaticSensors = 'device.automatic_sensors';
  static const sleepSync = 'device.sleep_sync';
  static const workoutSensors = 'device.workout_sensors';
  static const biometricTrends = 'device.biometric_trends';
  static const deviceSync = 'device.sync';
  static const batteryManagement = 'device.battery';
}
