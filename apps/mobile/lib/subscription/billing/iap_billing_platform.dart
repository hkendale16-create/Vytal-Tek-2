import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';

import '../entitlement_service.dart';

/// Shared StoreKit (Phase B) + Play Billing (Phase C) adapter via `in_app_purchase`.
///
/// Never grants entitlements. Successful store operations only return a
/// [PurchaseReceipt] for server verification (Phase D).
class InAppPurchaseBillingPlatform implements BillingPlatform {
  InAppPurchaseBillingPlatform({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final _pending = <String, Completer<BillingOperationResult>>{};
  final _lastPurchaseDetails = <String, PurchaseDetails>{};

  @override
  BillingPlatformKind get kind {
    if (kIsWeb) return BillingPlatformKind.unsupported;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS =>
        BillingPlatformKind.appleStoreKit,
      TargetPlatform.android => BillingPlatformKind.googlePlayBilling,
      _ => BillingPlatformKind.unsupported,
    };
  }

  void ensureListening() {
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) {
        for (final completer in _pending.values) {
          if (!completer.isCompleted) {
            completer.complete(
              BillingOperationResult(
                ok: false,
                message: 'Store purchase stream error: $error',
              ),
            );
          }
        }
        _pending.clear();
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
  Future<bool> get isAvailable async {
    if (kind == BillingPlatformKind.unsupported) return false;
    return _iap.isAvailable();
  }

  @override
  Future<List<StoreProductInfo>> queryProducts(Set<String> productIds) async {
    if (!await isAvailable) return const [];
    final response = await _iap.queryProductDetails(productIds);
    return response.productDetails
        .map(
          (p) => StoreProductInfo(
            id: p.id,
            title: p.title,
            description: p.description,
            priceLabel: p.price,
            rawPrice: p.rawPrice,
            currencyCode: p.currencyCode,
          ),
        )
        .toList();
  }

  @override
  Future<BillingOperationResult> purchase(String productId) async {
    ensureListening();
    if (!await isAvailable) return BillingOperationResult.notAvailable;

    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      return BillingOperationResult(
        ok: false,
        message:
            'Product "$productId" was not found in the store. Configure it in '
            'App Store Connect / Play Console sandbox first.',
        productId: productId,
      );
    }

    final product = response.productDetails.first;
    final completer = Completer<BillingOperationResult>();
    _pending[productId] = completer;

    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!started) {
      _pending.remove(productId);
      return BillingOperationResult(
        ok: false,
        message: 'Store did not start the purchase sheet.',
        productId: productId,
      );
    }

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pending.remove(productId);
        return BillingOperationResult(
          ok: false,
          message: 'Purchase timed out waiting for store confirmation.',
          productId: productId,
        );
      },
    );
  }

  @override
  Future<BillingOperationResult> changeSubscription({
    required String fromProductId,
    required String toProductId,
  }) async {
    ensureListening();
    if (!await isAvailable) return BillingOperationResult.notAvailable;

    if (kind == BillingPlatformKind.googlePlayBilling) {
      final changed = await _tryAndroidPlanChange(
        fromProductId: fromProductId,
        toProductId: toProductId,
      );
      if (changed != null) return changed;
    }

    // StoreKit (and Android fallback): purchase the target product.
    // Platforms apply official proration / replacement rules.
    final result = await purchase(toProductId);
    final receipt = result.receipt;
    if (receipt == null) return result;
    return BillingOperationResult(
      ok: result.ok,
      message: result.message,
      productId: result.productId,
      receipt: PurchaseReceipt(
        productId: receipt.productId,
        platform: receipt.platform,
        purchaseId: receipt.purchaseId,
        verificationData: receipt.verificationData,
        transactionDate: receipt.transactionDate,
        isUpgrade: true,
        previousProductId: fromProductId,
      ),
      requiresServerVerification: true,
    );
  }

  Future<BillingOperationResult?> _tryAndroidPlanChange({
    required String fromProductId,
    required String toProductId,
  }) async {
    try {
      final addition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final past = await addition.queryPastPurchases();
      GooglePlayPurchaseDetails? old;
      for (final purchase in past.pastPurchases) {
        if (purchase.productID == fromProductId) {
          old = purchase;
          break;
        }
      }
      if (old == null) return null;

      final response = await _iap.queryProductDetails({toProductId});
      if (response.productDetails.isEmpty) {
        return BillingOperationResult(
          ok: false,
          message: 'Product "$toProductId" was not found in Play Billing.',
          productId: toProductId,
        );
      }

      final completer = Completer<BillingOperationResult>();
      _pending[toProductId] = completer;
      final started = await _iap.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: response.productDetails.first,
          changeSubscriptionParam: ChangeSubscriptionParam(
            oldPurchaseDetails: old,
          ),
        ),
      );
      if (!started) {
        _pending.remove(toProductId);
        return null;
      }

      final result = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _pending.remove(toProductId);
          return BillingOperationResult(
            ok: false,
            message: 'Plan change timed out waiting for Play Billing.',
            productId: toProductId,
          );
        },
      );
      final receipt = result.receipt;
      if (receipt == null) return result;
      return BillingOperationResult(
        ok: result.ok,
        message: result.message,
        productId: result.productId,
        receipt: PurchaseReceipt(
          productId: receipt.productId,
          platform: receipt.platform,
          purchaseId: receipt.purchaseId,
          verificationData: receipt.verificationData,
          transactionDate: receipt.transactionDate,
          isUpgrade: true,
          previousProductId: fromProductId,
        ),
        requiresServerVerification: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<BillingOperationResult> restorePurchases() async {
    ensureListening();
    if (!await isAvailable) return BillingOperationResult.notAvailable;

    final completer = Completer<BillingOperationResult>();
    _pending['__restore__'] = completer;
    await _iap.restorePurchases();

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _pending.remove('__restore__');
        return const BillingOperationResult(
          ok: true,
          message: 'No active store subscriptions found to restore.',
          requiresServerVerification: false,
        );
      },
    );
  }

  @override
  Future<BillingOperationResult> openManageSubscriptions() async {
    final uri = switch (kind) {
      BillingPlatformKind.appleStoreKit =>
        Uri.parse('https://apps.apple.com/account/subscriptions'),
      BillingPlatformKind.googlePlayBilling => Uri.parse(
          'https://play.google.com/store/account/subscriptions',
        ),
      _ => null,
    };
    if (uri == null) {
      return const BillingOperationResult(
        ok: false,
        message: 'Manage Subscription is only available on iOS and Android.',
      );
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return BillingOperationResult(
      ok: launched,
      message: launched
          ? 'Opened platform subscription management.'
          : 'Could not open subscription management.',
      requiresServerVerification: false,
    );
  }

  /// Completes / acknowledges a store transaction after server verification.
  Future<void> acknowledgeAfterVerification(PurchaseReceipt receipt) async {
    final details = _lastPurchaseDetails.remove(receipt.purchaseId) ??
        _lastPurchaseDetails.remove(receipt.productId);
    if (details != null && details.pendingCompletePurchase) {
      await _iap.completePurchase(details);
    }
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      unawaited(_handlePurchase(purchase));
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) return;

    final productId = purchase.productID;
    final completer =
        _pending.remove(productId) ?? _pending.remove('__restore__');

    if (purchase.status == PurchaseStatus.error) {
      completer?.complete(
        BillingOperationResult(
          ok: false,
          message: purchase.error?.message ?? 'Store purchase failed.',
          productId: productId,
        ),
      );
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      return;
    }

    if (purchase.status == PurchaseStatus.canceled) {
      completer?.complete(
        BillingOperationResult(
          ok: false,
          message: 'Purchase canceled.',
          productId: productId,
        ),
      );
      return;
    }

    final receipt = PurchaseReceipt(
      productId: productId,
      platform: kind,
      purchaseId: purchase.purchaseID ?? productId,
      verificationData: purchase.verificationData.serverVerificationData,
      transactionDate: purchase.transactionDate == null
          ? null
          : DateTime.tryParse(purchase.transactionDate!),
    );

    _lastPurchaseDetails[purchase.purchaseID ?? productId] = purchase;
    completer?.complete(BillingOperationResult.pendingVerification(receipt));
  }
}
