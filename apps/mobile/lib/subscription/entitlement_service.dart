import '../domain/models/entitlements.dart';

/// Which store (or stub) owns digital subscription billing.
enum BillingPlatformKind {
  appleStoreKit,
  googlePlayBilling,
  sandbox,
  unsupported,
}

/// Opaque purchase / restore payload awaiting server verification.
class PurchaseReceipt {
  const PurchaseReceipt({
    required this.productId,
    required this.platform,
    required this.purchaseId,
    required this.verificationData,
    this.transactionDate,
    this.isUpgrade = false,
    this.previousProductId,
  });

  final String productId;
  final BillingPlatformKind platform;
  final String purchaseId;

  /// Store-signed payload (StoreKit JWS / Play purchase token). Never trust alone.
  final String verificationData;
  final DateTime? transactionDate;
  final bool isUpgrade;
  final String? previousProductId;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'platform': platform.name,
        'purchaseId': purchaseId,
        'verificationData': verificationData,
        'transactionDate': transactionDate?.toIso8601String(),
        'isUpgrade': isUpgrade,
        'previousProductId': previousProductId,
      };
}

/// Result of a billing operation — never grants entitlements by itself.
class BillingOperationResult {
  const BillingOperationResult({
    required this.ok,
    required this.message,
    this.productId,
    this.receipt,
    this.requiresServerVerification = true,
  });

  final bool ok;
  final String message;
  final String? productId;
  final PurchaseReceipt? receipt;

  /// Paid grants must wait for backend verification (Phase D).
  final bool requiresServerVerification;

  static const notAvailable = BillingOperationResult(
    ok: false,
    message:
        'In-app purchases are unavailable on this device. Use a StoreKit / '
        'Play Billing sandbox build, or Sandbox billing in tests.',
    requiresServerVerification: true,
  );

  static BillingOperationResult pendingVerification(PurchaseReceipt receipt) =>
      BillingOperationResult(
        ok: true,
        message: 'Purchase received — verifying with Vytal servers…',
        productId: receipt.productId,
        receipt: receipt,
        requiresServerVerification: true,
      );
}

/// Abstract billing surface — StoreKit (B), Play Billing (C), sandbox, or stub.
abstract class BillingPlatform {
  BillingPlatformKind get kind;

  Future<bool> get isAvailable;

  /// Query store product details when the platform supports it.
  Future<List<StoreProductInfo>> queryProducts(Set<String> productIds) async =>
      const [];

  Future<BillingOperationResult> purchase(String productId);

  Future<BillingOperationResult> restorePurchases();

  Future<BillingOperationResult> openManageSubscriptions();

  /// Platform upgrade / plan change when supported.
  Future<BillingOperationResult> changeSubscription({
    required String fromProductId,
    required String toProductId,
  }) async {
    return purchase(toProductId);
  }
}

class StoreProductInfo {
  const StoreProductInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.priceLabel,
    this.rawPrice,
    this.currencyCode,
  });

  final String id;
  final String title;
  final String description;
  final String priceLabel;
  final double? rawPrice;
  final String? currencyCode;
}

/// Stub used when neither store nor sandbox billing is available.
class UnsupportedBillingPlatform implements BillingPlatform {
  const UnsupportedBillingPlatform();

  @override
  BillingPlatformKind get kind => BillingPlatformKind.unsupported;

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<List<StoreProductInfo>> queryProducts(Set<String> productIds) async =>
      const [];

  @override
  Future<BillingOperationResult> purchase(String productId) async =>
      BillingOperationResult.notAvailable;

  @override
  Future<BillingOperationResult> restorePurchases() async =>
      BillingOperationResult.notAvailable;

  @override
  Future<BillingOperationResult> changeSubscription({
    required String fromProductId,
    required String toProductId,
  }) async =>
      BillingOperationResult.notAvailable;

  @override
  Future<BillingOperationResult> openManageSubscriptions() async =>
      const BillingOperationResult(
        ok: false,
        message:
            'Manage Subscription opens the App Store or Play subscription sheet '
            'when StoreKit / Play Billing is available.',
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

  String lockedMessage(String key, {required String planLabel}) {
    return '${EntitlementKeys.displayName(key)} is included with $planLabel.';
  }
}
