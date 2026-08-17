import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/entitlements.dart';
import '../state/app_session_controller.dart';
import 'billing/iap_billing_platform.dart';
import 'billing/sandbox_billing_platform.dart';
import 'entitlement_service.dart';
import 'product_catalog.dart';
import 'verification/entitlement_verifier.dart';

final subscriptionCatalogProvider = Provider<SubscriptionCatalog>((ref) {
  return SubscriptionCatalog.standard;
});

/// Override in tests with [SandboxBillingPlatform].
final billingPlatformProvider = Provider<BillingPlatform>((ref) {
  return createDefaultBillingPlatform();
});

/// Override in tests with [MockEntitlementVerifier].
final entitlementVerifierProvider = Provider<EntitlementVerifier>((ref) {
  // Production builds should inject [HttpEntitlementVerifier] with a real API.
  // Default mock accepts sandbox tokens only — StoreKit/Play need HTTP verify.
  return MockEntitlementVerifier(
    catalog: ref.watch(subscriptionCatalogProvider),
  );
});

final entitlementServiceProvider = Provider<EntitlementService>((ref) {
  final entitlements = ref.watch(appSessionProvider).entitlements;
  return EntitlementService(entitlements);
});

final subscriptionControllerProvider =
    Provider<SubscriptionController>((ref) {
  return SubscriptionController(ref);
});

BillingPlatform createDefaultBillingPlatform() {
  if (kIsWeb) return const UnsupportedBillingPlatform();
  // Prefer real IAP on mobile; it reports unavailable until store products exist.
  return InAppPurchaseBillingPlatform();
}

/// Subscription actions — purchase → verify → apply. Never skip verification.
class SubscriptionController {
  SubscriptionController(this._ref);

  final Ref _ref;

  EntitlementService get entitlements =>
      _ref.read(entitlementServiceProvider);

  SubscriptionCatalog get catalog => _ref.read(subscriptionCatalogProvider);

  BillingPlatform get billing => _ref.read(billingPlatformProvider);

  EntitlementVerifier get verifier => _ref.read(entitlementVerifierProvider);

  Future<BillingOperationResult> purchase(SubscriptionProduct product) async {
    if (product.tier == SubscriptionTier.free) {
      return downgradeToFree();
    }

    final current = entitlements.tier;
    if (current != SubscriptionTier.free &&
        current != product.tier &&
        entitlements.snapshot.productId != null) {
      return changePlan(
        fromProductId: entitlements.snapshot.productId!,
        to: product,
      );
    }

    final billed = await billing.purchase(product.id);
    return _verifyAndApply(billed);
  }

  /// Phase E — upgrade / downgrade through platform change APIs when possible.
  Future<BillingOperationResult> changePlan({
    required String fromProductId,
    required SubscriptionProduct to,
  }) async {
    if (to.tier == SubscriptionTier.free) {
      return downgradeToFree();
    }
    final billed = await billing.changeSubscription(
      fromProductId: fromProductId,
      toProductId: to.id,
    );
    return _verifyAndApply(billed);
  }

  /// Cancel is platform-managed; we only open the store sheet and explain timing.
  Future<BillingOperationResult> cancelSubscription() async {
    final managed = await billing.openManageSubscriptions();
    if (!managed.ok) return managed;
    return BillingOperationResult(
      ok: true,
      message:
          '${managed.message} Cancellation keeps access until the period ends; '
          'entitlements update after the store notifies Vytal servers.',
      requiresServerVerification: false,
    );
  }

  Future<BillingOperationResult> restorePurchases() async {
    final billed = await billing.restorePurchases();
    return _verifyAndApply(billed);
  }

  Future<BillingOperationResult> openManageSubscriptions() =>
      billing.openManageSubscriptions();

  Future<BillingOperationResult> downgradeToFree() async {
    // Immediate free switch is only for users who were never on a paid store plan,
    // or after server confirms expiry. Paid cancels must use the platform sheet.
    final snapshot = entitlements.snapshot;
    if (snapshot.isPaidTier &&
        snapshot.verificationSource ==
            EntitlementVerificationSource.serverVerified &&
        snapshot.lifecycle.grantsAccess) {
      final managed = await cancelSubscription();
      return BillingOperationResult(
        ok: managed.ok,
        message:
            'Paid plans cancel through the App Store / Play. ${managed.message}',
        requiresServerVerification: false,
      );
    }
    await _apply(EntitlementSnapshot.freeDefaults);
    return const BillingOperationResult(
      ok: true,
      message: 'You are on the Free / Core plan.',
      requiresServerVerification: false,
    );
  }

  /// Applies App Store / Play server notification style updates (Phase D).
  Future<EntitlementVerificationResult> applyLifecycleNotification({
    required String productId,
    required SubscriptionLifecycle lifecycle,
    DateTime? expiresAt,
    DateTime? renewsAt,
    bool willRenew = true,
  }) async {
    final result = await verifier.applyLifecycleNotification(
      productId: productId,
      lifecycle: lifecycle,
      expiresAt: expiresAt,
      renewsAt: renewsAt,
      willRenew: willRenew,
    );
    if (result.ok && result.snapshot != null) {
      await _apply(result.snapshot!);
    }
    return result;
  }

  Future<BillingOperationResult> _verifyAndApply(
    BillingOperationResult billed,
  ) async {
    if (!billed.ok) return billed;
    final receipt = billed.receipt;
    if (receipt == null) {
      // Restore with nothing to verify.
      if (!billed.requiresServerVerification) return billed;
      return const BillingOperationResult(
        ok: false,
        message: 'Store returned success without a receipt — premium not granted.',
      );
    }

    final verified = await verifier.verify(receipt);
    if (!verified.ok || verified.snapshot == null) {
      return BillingOperationResult(
        ok: false,
        message: verified.message,
        productId: receipt.productId,
        receipt: receipt,
      );
    }

    await _apply(verified.snapshot!);
    await _acknowledgeIfNeeded(receipt);

    return BillingOperationResult(
      ok: true,
      message: verified.message,
      productId: receipt.productId,
      receipt: receipt,
      requiresServerVerification: false,
    );
  }

  Future<void> _acknowledgeIfNeeded(PurchaseReceipt receipt) async {
    final platform = billing;
    if (platform is InAppPurchaseBillingPlatform) {
      await platform.acknowledgeAfterVerification(receipt);
    }
  }

  Future<void> _apply(EntitlementSnapshot snapshot) async {
    await _ref.read(appSessionProvider.notifier).setEntitlements(snapshot);
  }

  /// Phase F — after launch, re-verify if disk restore left an untrusted hint.
  ///
  /// Free users / no product hint: no store traffic.
  Future<BillingOperationResult?> refreshAfterLaunch() async {
    final snapshot = entitlements.snapshot;
    if (!EntitlementSecurity.shouldAttemptRestore(snapshot)) {
      return null;
    }
    return restorePurchases();
  }

  /// Sandbox UI preview only — clearly labeled, never production authority.
  ///
  /// Phase F: no-ops in release builds.
  Future<BillingOperationResult> applySandboxPreview(SubscriptionTier tier) async {
    if (kReleaseMode) {
      return const BillingOperationResult(
        ok: false,
        message: 'Sandbox preview is disabled in release builds.',
        requiresServerVerification: false,
      );
    }
    final product = catalog.productForTier(tier);
    if (tier == SubscriptionTier.free) {
      await _apply(EntitlementSnapshot.freeDefaults);
      return const BillingOperationResult(
        ok: true,
        message: 'Sandbox preview: Free / Core',
        requiresServerVerification: false,
      );
    }
    final renews = DateTime.now().toUtc().add(const Duration(days: 30));
    await _apply(
      EntitlementSnapshot.forTier(
        tier,
        enabled: product.entitlements,
        productId: product.id,
        renewsAt: renews,
        expiresAt: renews,
        willRenew: true,
        verificationSource: EntitlementVerificationSource.sandboxPreview,
      ),
    );
    return BillingOperationResult(
      ok: true,
      message: 'Sandbox preview: ${tier.displayLabel}',
      requiresServerVerification: false,
    );
  }
}
