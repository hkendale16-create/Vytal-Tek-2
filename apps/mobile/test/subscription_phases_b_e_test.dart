import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/domain/models/entitlements.dart';
import 'package:vytal_tek/state/app_session_controller.dart';
import 'package:vytal_tek/subscription/billing/sandbox_billing_platform.dart';
import 'package:vytal_tek/subscription/entitlement_service.dart';
import 'package:vytal_tek/subscription/product_catalog.dart';
import 'package:vytal_tek/subscription/subscription_controller.dart';
import 'package:vytal_tek/subscription/verification/entitlement_verifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SandboxBillingPlatform sandbox;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sandbox = SandboxBillingPlatform();
    container = ProviderContainer(
      overrides: [
        billingPlatformProvider.overrideWithValue(sandbox),
        entitlementVerifierProvider.overrideWithValue(
          MockEntitlementVerifier(),
        ),
      ],
    );
    // Allow session restore to settle.
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() => container.dispose());

  SubscriptionController controller() =>
      container.read(subscriptionControllerProvider);

  AppSession session() => container.read(appSessionProvider);

  group('Phase B/C sandbox billing', () {
    test('purchase emits receipt without granting until verify', () async {
      final billed = await sandbox.purchase('vytal.plus.monthly');
      expect(billed.ok, isTrue);
      expect(billed.requiresServerVerification, isTrue);
      expect(billed.receipt, isNotNull);
      expect(session().entitlements.tier, SubscriptionTier.free);
    });

    test('storekit-shaped flow grants only after mock verification', () async {
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      final result = await controller().purchase(plus);
      expect(result.ok, isTrue);
      expect(session().entitlements.tier, SubscriptionTier.plus);
      expect(
        session().entitlements.verificationSource,
        EntitlementVerificationSource.serverVerified,
      );
      expect(
        session().entitlements.canUse(EntitlementKeys.analyticsAdvanced),
        isTrue,
      );
    });

    test('failed sandbox purchase does not unlock premium', () async {
      sandbox.failNextPurchase = true;
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      final result = await controller().purchase(plus);
      expect(result.ok, isFalse);
      expect(session().entitlements.tier, SubscriptionTier.free);
    });
  });

  group('Phase D verification', () {
    test('mock verifier rejects non-sandbox store tokens', () async {
      final verifier = MockEntitlementVerifier();
      final result = await verifier.verify(
        const PurchaseReceipt(
          productId: 'vytal.plus.monthly',
          platform: BillingPlatformKind.appleStoreKit,
          purchaseId: 'txn-1',
          verificationData: 'real.storekit.jws.payload',
        ),
      );
      expect(result.ok, isFalse);
      expect(result.snapshot, isNull);
    });

    test('http verifier fails closed without API', () async {
      final verifier = HttpEntitlementVerifier(
        endpoint: Uri.parse('https://api.vytaltek.example/entitlements/verify'),
      );
      final result = await verifier.verify(
        const PurchaseReceipt(
          productId: 'vytal.plus.monthly',
          platform: BillingPlatformKind.googlePlayBilling,
          purchaseId: 'gp-1',
          verificationData: 'play.purchase.token',
        ),
      );
      expect(result.ok, isFalse);
      expect(session().entitlements.tier, SubscriptionTier.free);
    });

    test('http verifier applies server snapshot when ok', () async {
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      final verifier = HttpEntitlementVerifier(
        endpoint: Uri.parse('https://api.vytaltek.example/entitlements/verify'),
        postJson: (url, body) async => {
          'ok': true,
          'message': 'Server verified Plus',
          'entitlements': EntitlementSnapshot.forTier(
            SubscriptionTier.plus,
            enabled: plus.entitlements,
            productId: plus.id,
            verificationSource: EntitlementVerificationSource.serverVerified,
          ).toJson(),
        },
      );
      container.dispose();
      container = ProviderContainer(
        overrides: [
          billingPlatformProvider.overrideWithValue(sandbox),
          entitlementVerifierProvider.overrideWithValue(verifier),
        ],
      );
      final result = await container
          .read(subscriptionControllerProvider)
          .purchase(plus);
      expect(result.ok, isTrue);
      expect(
        container.read(appSessionProvider).entitlements.tier,
        SubscriptionTier.plus,
      );
    });

    test('client isPremium style payload cannot skip verification', () async {
      final billed = await sandbox.purchase('vytal.pro.monthly');
      expect(billed.receipt, isNotNull);
      final rejected = await MockEntitlementVerifier().verify(
        PurchaseReceipt(
          productId: billed.receipt!.productId,
          platform: BillingPlatformKind.sandbox,
          purchaseId: billed.receipt!.purchaseId,
          verificationData: 'isPremium=true',
        ),
      );
      expect(rejected.ok, isFalse);
    });
  });

  group('Phase E lifecycle', () {
    test('upgrade plus → pro verifies and swaps entitlements', () async {
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      final pro = SubscriptionCatalog.standard.productForTier(SubscriptionTier.pro);
      await controller().purchase(plus);
      expect(session().entitlements.tier, SubscriptionTier.plus);

      final upgraded = await controller().purchase(pro);
      expect(upgraded.ok, isTrue);
      expect(session().entitlements.tier, SubscriptionTier.pro);
      expect(session().entitlements.canUse(EntitlementKeys.aiAdvanced), isTrue);
      expect(sandbox.history.last.isUpgrade, isTrue);
    });

    test('restore reapplies last verified sandbox receipt', () async {
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      await controller().purchase(plus);
      await container.read(appSessionProvider.notifier).setEntitlements(
            EntitlementSnapshot.freeDefaults,
          );
      expect(session().entitlements.tier, SubscriptionTier.free);

      final restored = await controller().restorePurchases();
      expect(restored.ok, isTrue);
      expect(session().entitlements.tier, SubscriptionTier.plus);
    });

    test('cancel opens manage sheet without deleting data entitlements mid-period',
        () async {
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      await controller().purchase(plus);
      final canceled = await controller().cancelSubscription();
      expect(canceled.ok, isTrue);
      expect(
        session().entitlements.canUse(EntitlementKeys.analyticsAdvanced),
        isTrue,
      );
    });

    test('expired lifecycle notification locks premium and keeps free core',
        () async {
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      await controller().purchase(plus);
      final expired = await controller().applyLifecycleNotification(
        productId: plus.id,
        lifecycle: SubscriptionLifecycle.expired,
        willRenew: false,
        expiresAt: DateTime.now().toUtc(),
      );
      expect(expired.ok, isTrue);
      expect(session().entitlements.tier, SubscriptionTier.free);
      expect(session().entitlements.canUse(EntitlementKeys.aiBasic), isTrue);
      expect(
        session().entitlements.canUse(EntitlementKeys.analyticsAdvanced),
        isFalse,
      );
    });

    test('grace period keeps advanced access', () async {
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      await controller().purchase(plus);
      final grace = await controller().applyLifecycleNotification(
        productId: plus.id,
        lifecycle: SubscriptionLifecycle.gracePeriod,
        renewsAt: DateTime.now().toUtc().add(const Duration(days: 3)),
      );
      expect(grace.ok, isTrue);
      expect(session().entitlements.lifecycle, SubscriptionLifecycle.gracePeriod);
      expect(
        session().entitlements.canUse(EntitlementKeys.sleepAdvanced),
        isTrue,
      );
    });
  });
}
