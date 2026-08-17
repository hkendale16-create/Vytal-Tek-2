import '../domain/models/entitlements.dart';

/// Which store (or stub) owns digital subscription billing.
enum BillingPlatformKind {
  appleStoreKit,
  googlePlayBilling,
  unsupported,
}

/// Result of a billing operation — never grants entitlements by itself.
class BillingOperationResult {
  const BillingOperationResult({
    required this.ok,
    required this.message,
    this.productId,
    this.requiresServerVerification = true,
  });

  final bool ok;
  final String message;
  final String? productId;

  /// Paid grants must wait for backend verification (Phase D).
  final bool requiresServerVerification;

  static const notAvailable = BillingOperationResult(
    ok: false,
    message:
        'In-app purchases are not wired yet. StoreKit (iOS) and Play Billing '
        '(Android) arrive in Subscription Phases B and C.',
    requiresServerVerification: true,
  );
}

/// Abstract billing surface. Platform implementations land in Phases B/C.
abstract class BillingPlatform {
  BillingPlatformKind get kind;

  Future<bool> get isAvailable;

  Future<BillingOperationResult> purchase(String productId);

  Future<BillingOperationResult> restorePurchases();

  Future<BillingOperationResult> openManageSubscriptions();
}

/// Stub used until StoreKit / Play Billing adapters ship.
class UnsupportedBillingPlatform implements BillingPlatform {
  const UnsupportedBillingPlatform();

  @override
  BillingPlatformKind get kind => BillingPlatformKind.unsupported;

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<BillingOperationResult> purchase(String productId) async =>
      BillingOperationResult.notAvailable;

  @override
  Future<BillingOperationResult> restorePurchases() async =>
      BillingOperationResult.notAvailable;

  @override
  Future<BillingOperationResult> openManageSubscriptions() async =>
      const BillingOperationResult(
        ok: false,
        message:
            'Manage Subscription opens the platform subscription sheet once '
            'StoreKit / Play Billing are connected.',
      );
}

/// Answers entitlement questions from one place — do not scatter checks in UI.
class EntitlementService {
  const EntitlementService(this.snapshot);

  final EntitlementSnapshot snapshot;

  bool canUse(String key) => snapshot.canUse(key);

  bool get isSubscribed => snapshot.isSubscribed;

  SubscriptionTier get tier => snapshot.tier;

  SubscriptionLifecycle get lifecycle => snapshot.lifecycle;

  bool get isExpiringSoon {
    final end = snapshot.expiresAt ?? snapshot.renewsAt;
    if (end == null || !snapshot.lifecycle.grantsAccess) return false;
    return end.difference(DateTime.now().toUtc()) <= const Duration(days: 7);
  }

  bool get isInGraceOrRetry =>
      snapshot.lifecycle == SubscriptionLifecycle.gracePeriod ||
      snapshot.lifecycle == SubscriptionLifecycle.billingRetry;

  DateTime? get entitlementEndsAt => snapshot.expiresAt ?? snapshot.renewsAt;

  /// Soft paywall copy — never claim the user "must" subscribe.
  String lockedMessage(String key, {required String planLabel}) {
    return '${EntitlementKeys.displayName(key)} is included with $planLabel.';
  }
}
