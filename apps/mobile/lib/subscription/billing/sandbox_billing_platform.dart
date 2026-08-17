import '../entitlement_service.dart';

/// Deterministic sandbox billing for tests + local lifecycle drills (Phase B/C).
///
/// Emits receipts only — never applies entitlements. Verification is Phase D.
class SandboxBillingPlatform implements BillingPlatform {
  SandboxBillingPlatform({
    this.availableProducts = const {
      'vytal.plus.monthly',
      'vytal.pro.monthly',
    },
    this.failNextPurchase = false,
  });

  final Set<String> availableProducts;
  bool failNextPurchase;

  /// Last receipts produced (purchase / restore / change).
  final List<PurchaseReceipt> history = [];

  @override
  BillingPlatformKind get kind => BillingPlatformKind.sandbox;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<List<StoreProductInfo>> queryProducts(Set<String> productIds) async {
    return productIds
        .where(availableProducts.contains)
        .map(
          (id) => StoreProductInfo(
            id: id,
            title: id,
            description: 'Sandbox product',
            priceLabel: id.contains('pro') ? '\$14.99' : '\$9.99',
            rawPrice: id.contains('pro') ? 14.99 : 9.99,
            currencyCode: 'USD',
          ),
        )
        .toList();
  }

  @override
  Future<BillingOperationResult> purchase(String productId) async {
    if (failNextPurchase) {
      failNextPurchase = false;
      return BillingOperationResult(
        ok: false,
        message: 'Sandbox purchase failed (injected).',
        productId: productId,
      );
    }
    if (!availableProducts.contains(productId)) {
      return BillingOperationResult(
        ok: false,
        message: 'Sandbox product not found: $productId',
        productId: productId,
      );
    }
    final receipt = _receipt(productId);
    history.add(receipt);
    return BillingOperationResult.pendingVerification(receipt);
  }

  @override
  Future<BillingOperationResult> changeSubscription({
    required String fromProductId,
    required String toProductId,
  }) async {
    if (!availableProducts.contains(toProductId)) {
      return BillingOperationResult(
        ok: false,
        message: 'Sandbox product not found: $toProductId',
        productId: toProductId,
      );
    }
    final receipt = _receipt(
      toProductId,
      isUpgrade: true,
      previousProductId: fromProductId,
    );
    history.add(receipt);
    return BillingOperationResult.pendingVerification(receipt);
  }

  @override
  Future<BillingOperationResult> restorePurchases() async {
    if (history.isEmpty) {
      return const BillingOperationResult(
        ok: true,
        message: 'No sandbox purchases to restore.',
        requiresServerVerification: false,
      );
    }
    final latest = history.last;
    return BillingOperationResult.pendingVerification(latest);
  }

  @override
  Future<BillingOperationResult> openManageSubscriptions() async {
    return const BillingOperationResult(
      ok: true,
      message: 'Sandbox manage sheet — cancel takes effect at period end.',
      requiresServerVerification: false,
    );
  }

  PurchaseReceipt _receipt(
    String productId, {
    bool isUpgrade = false,
    String? previousProductId,
  }) {
    final now = DateTime.now().toUtc();
    return PurchaseReceipt(
      productId: productId,
      platform: BillingPlatformKind.sandbox,
      purchaseId: 'sandbox-$productId-${now.millisecondsSinceEpoch}',
      verificationData: 'sandbox.token.$productId.${now.millisecondsSinceEpoch}',
      transactionDate: now,
      isUpgrade: isUpgrade,
      previousProductId: previousProductId,
    );
  }
}
