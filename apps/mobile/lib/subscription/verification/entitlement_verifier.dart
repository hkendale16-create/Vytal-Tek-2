import '../../domain/models/entitlements.dart';
import '../entitlement_service.dart';
import '../product_catalog.dart';

/// Result of server-side purchase verification (Phase D).
class EntitlementVerificationResult {
  const EntitlementVerificationResult({
    required this.ok,
    required this.message,
    this.snapshot,
  });

  final bool ok;
  final String message;
  final EntitlementSnapshot? snapshot;

  static const rejected = EntitlementVerificationResult(
    ok: false,
    message: 'Purchase could not be verified. Premium was not granted.',
  );
}

/// Authoritative entitlement verification — never trust the mobile client alone.
abstract class EntitlementVerifier {
  Future<EntitlementVerificationResult> verify(PurchaseReceipt receipt);

  /// Applies App Store / Play server notification style lifecycle updates.
  Future<EntitlementVerificationResult> applyLifecycleNotification({
    required String productId,
    required SubscriptionLifecycle lifecycle,
    DateTime? expiresAt,
    DateTime? renewsAt,
    bool willRenew = true,
  });
}

/// Local mock verifier for tests + offline sandbox drills.
///
/// Accepts only `sandbox.token.*` verification payloads. Real StoreKit / Play
/// tokens must go through [HttpEntitlementVerifier] in production.
class MockEntitlementVerifier implements EntitlementVerifier {
  MockEntitlementVerifier({
    SubscriptionCatalog? catalog,
    this.acceptSandboxTokensOnly = true,
  }) : catalog = catalog ?? SubscriptionCatalog.standard;

  final SubscriptionCatalog catalog;
  final bool acceptSandboxTokensOnly;

  @override
  Future<EntitlementVerificationResult> verify(PurchaseReceipt receipt) async {
    if (acceptSandboxTokensOnly &&
        !receipt.verificationData.startsWith('sandbox.token.')) {
      return const EntitlementVerificationResult(
        ok: false,
        message:
            'Mock verifier rejects non-sandbox tokens. Use the HTTP verifier '
            'against the entitlement API for StoreKit / Play receipts.',
      );
    }

    final product = catalog.byId(receipt.productId);
    if (product == null || product.tier == SubscriptionTier.free) {
      return EntitlementVerificationResult(
        ok: false,
        message: 'Unknown or free product: ${receipt.productId}',
      );
    }

    final renews = DateTime.now().toUtc().add(const Duration(days: 30));
    final snapshot = EntitlementSnapshot.forTier(
      product.tier,
      enabled: product.entitlements,
      productId: product.id,
      renewsAt: renews,
      expiresAt: renews,
      willRenew: true,
      verificationSource: EntitlementVerificationSource.serverVerified,
    );

    return EntitlementVerificationResult(
      ok: true,
      message: 'Verified ${product.displayName} (mock server).',
      snapshot: snapshot,
    );
  }

  @override
  Future<EntitlementVerificationResult> applyLifecycleNotification({
    required String productId,
    required SubscriptionLifecycle lifecycle,
    DateTime? expiresAt,
    DateTime? renewsAt,
    bool willRenew = true,
  }) async {
    final product = catalog.byId(productId);
    if (product == null) {
      return EntitlementVerificationResult(
        ok: false,
        message: 'Unknown product for lifecycle update: $productId',
      );
    }

    if (!lifecycle.grantsAccess) {
      return EntitlementVerificationResult(
        ok: true,
        message: 'Lifecycle ${lifecycle.name} — premium locked, data retained.',
        snapshot: EntitlementSnapshot.freeDefaults.copyWith(
          lifecycle: lifecycle,
          productId: productId,
          expiresAt: expiresAt,
          renewsAt: renewsAt,
          willRenew: willRenew,
          verificationSource: EntitlementVerificationSource.serverVerified,
          lastVerifiedAt: DateTime.now().toUtc(),
        ),
      );
    }

    final snapshot = EntitlementSnapshot.forTier(
      product.tier,
      enabled: product.entitlements,
      lifecycle: lifecycle,
      productId: product.id,
      expiresAt: expiresAt,
      renewsAt: renewsAt,
      willRenew: willRenew,
      verificationSource: EntitlementVerificationSource.serverVerified,
    );

    return EntitlementVerificationResult(
      ok: true,
      message: 'Lifecycle updated to ${lifecycle.label}.',
      snapshot: snapshot,
    );
  }
}

/// HTTP verifier that posts receipts to the Vytal entitlement API (Phase D).
///
/// Until a backend URL is configured, calls fail closed (no premium grant).
class HttpEntitlementVerifier implements EntitlementVerifier {
  HttpEntitlementVerifier({
    required this.endpoint,
    SubscriptionCatalog? catalog,
    this.postJson,
  }) : catalog = catalog ?? SubscriptionCatalog.standard;

  final Uri endpoint;
  final SubscriptionCatalog catalog;

  /// Injectable HTTP POST for tests. Returns decoded JSON map.
  final Future<Map<String, dynamic>> Function(
    Uri url,
    Map<String, dynamic> body,
  )? postJson;

  @override
  Future<EntitlementVerificationResult> verify(PurchaseReceipt receipt) async {
    final post = postJson;
    if (post == null) {
      return const EntitlementVerificationResult(
        ok: false,
        message:
            'Entitlement API is not configured. Premium was not granted. '
            'Set VYTAL_ENTITLEMENT_API or inject postJson for verification.',
      );
    }

    try {
      final json = await post(endpoint, {
        'receipt': receipt.toJson(),
      });
      return _parse(json);
    } catch (error) {
      return EntitlementVerificationResult(
        ok: false,
        message: 'Verification request failed: $error',
      );
    }
  }

  @override
  Future<EntitlementVerificationResult> applyLifecycleNotification({
    required String productId,
    required SubscriptionLifecycle lifecycle,
    DateTime? expiresAt,
    DateTime? renewsAt,
    bool willRenew = true,
  }) async {
    final post = postJson;
    if (post == null) {
      return const EntitlementVerificationResult(
        ok: false,
        message: 'Entitlement API is not configured for lifecycle updates.',
      );
    }
    try {
      final json = await post(endpoint.resolve('lifecycle'), {
        'productId': productId,
        'lifecycle': lifecycle.name,
        'expiresAt': expiresAt?.toIso8601String(),
        'renewsAt': renewsAt?.toIso8601String(),
        'willRenew': willRenew,
      });
      return _parse(json);
    } catch (error) {
      return EntitlementVerificationResult(
        ok: false,
        message: 'Lifecycle verification failed: $error',
      );
    }
  }

  EntitlementVerificationResult _parse(Map<String, dynamic> json) {
    if (json['ok'] != true) {
      return EntitlementVerificationResult(
        ok: false,
        message: (json['message'] as String?) ??
            EntitlementVerificationResult.rejected.message,
      );
    }
    final raw = json['entitlements'];
    if (raw is! Map<String, dynamic>) {
      return const EntitlementVerificationResult(
        ok: false,
        message: 'Verifier response missing entitlements object.',
      );
    }
    final snapshot = EntitlementSnapshot.fromJson(raw).copyWith(
      verificationSource: EntitlementVerificationSource.serverVerified,
      lastVerifiedAt: DateTime.now().toUtc(),
    );
    // Refuse to accept client-shaped "premium" without a paid tier + access.
    if (snapshot.isPaidTier && !snapshot.lifecycle.grantsAccess) {
      return EntitlementVerificationResult(
        ok: true,
        message: (json['message'] as String?) ?? 'Subscription inactive.',
        snapshot: EntitlementSnapshot.freeDefaults.copyWith(
          lifecycle: snapshot.lifecycle,
          verificationSource: EntitlementVerificationSource.serverVerified,
        ),
      );
    }
    return EntitlementVerificationResult(
      ok: true,
      message: (json['message'] as String?) ?? 'Entitlements verified.',
      snapshot: snapshot,
    );
  }
}
