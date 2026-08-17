import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/entitlements.dart';
import '../state/app_session_controller.dart';
import 'entitlement_service.dart';
import 'product_catalog.dart';

final subscriptionCatalogProvider = Provider<SubscriptionCatalog>((ref) {
  return SubscriptionCatalog.standard;
});

final billingPlatformProvider = Provider<BillingPlatform>((ref) {
  return const UnsupportedBillingPlatform();
});

final entitlementServiceProvider = Provider<EntitlementService>((ref) {
  final entitlements = ref.watch(appSessionProvider).entitlements;
  return EntitlementService(entitlements);
});

/// Subscription actions that always go through the central layer.
final subscriptionControllerProvider =
    Provider<SubscriptionController>((ref) {
  return SubscriptionController(ref);
});

class SubscriptionController {
  SubscriptionController(this._ref);

  final Ref _ref;

  EntitlementService get entitlements =>
      _ref.read(entitlementServiceProvider);

  SubscriptionCatalog get catalog => _ref.read(subscriptionCatalogProvider);

  BillingPlatform get billing => _ref.read(billingPlatformProvider);

  Future<BillingOperationResult> purchase(SubscriptionProduct product) async {
    if (product.tier == SubscriptionTier.free) {
      await _applyFree();
      return const BillingOperationResult(
        ok: true,
        message: 'You are on the Free / Core plan.',
        requiresServerVerification: false,
      );
    }
    // Phase A: no live IAP. Do not grant premium from the client.
    return billing.purchase(product.id);
  }

  Future<BillingOperationResult> restorePurchases() =>
      billing.restorePurchases();

  Future<BillingOperationResult> openManageSubscriptions() =>
      billing.openManageSubscriptions();

  Future<void> _applyFree() async {
    await _ref.read(appSessionProvider.notifier).setEntitlements(
          EntitlementSnapshot.freeDefaults,
        );
  }

  /// Sandbox UI preview only — clearly labeled, never production authority.
  ///
  /// Used so designers/QA can review Plus/Pro gates before StoreKit ships.
  Future<void> applySandboxPreview(SubscriptionTier tier) async {
    final product = catalog.productForTier(tier);
    if (tier == SubscriptionTier.free) {
      await _applyFree();
      return;
    }
    final renews = DateTime.now().toUtc().add(const Duration(days: 30));
    await _ref.read(appSessionProvider.notifier).setEntitlements(
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
  }
}
