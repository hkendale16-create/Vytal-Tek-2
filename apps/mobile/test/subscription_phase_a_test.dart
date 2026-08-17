import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vytal_tek/domain/models/entitlements.dart';
import 'package:vytal_tek/subscription/entitlement_service.dart';
import 'package:vytal_tek/subscription/product_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('catalog entitlement matrix', () {
    final catalog = SubscriptionCatalog.standard;

    test('free includes only core keys', () {
      final free = catalog.productForTier(SubscriptionTier.free);
      expect(free.includes(EntitlementKeys.aiBasic), isTrue);
      expect(free.includes(EntitlementKeys.analyticsBasic), isTrue);
      expect(free.includes(EntitlementKeys.workoutsCustom), isTrue);
      expect(free.includes(EntitlementKeys.aiAdvanced), isFalse);
      expect(free.includes(EntitlementKeys.analyticsAdvanced), isFalse);
      expect(free.includes(EntitlementKeys.digitalBodyAdvanced), isFalse);
    });

    test('plus unlocks advanced analytics/sleep/recovery but not pro AI body', () {
      final plus = catalog.productForTier(SubscriptionTier.plus);
      expect(plus.includes(EntitlementKeys.analyticsAdvanced), isTrue);
      expect(plus.includes(EntitlementKeys.sleepAdvanced), isTrue);
      expect(plus.includes(EntitlementKeys.recoveryAdvanced), isTrue);
      expect(plus.includes(EntitlementKeys.workoutsAiGenerated), isTrue);
      expect(plus.includes(EntitlementKeys.aiAdvanced), isFalse);
      expect(plus.includes(EntitlementKeys.digitalBodyAdvanced), isFalse);
    });

    test('pro includes all catalog entitlement keys', () {
      final pro = catalog.productForTier(SubscriptionTier.pro);
      for (final key in EntitlementKeys.all) {
        expect(pro.includes(key), isTrue, reason: key);
      }
    });

    test('required plan labels point at lowest tier', () {
      expect(
        catalog.requiredPlanLabel(EntitlementKeys.aiBasic),
        contains('Free'),
      );
      expect(
        catalog.requiredPlanLabel(EntitlementKeys.analyticsAdvanced),
        contains('Plus'),
      );
      expect(
        catalog.requiredPlanLabel(EntitlementKeys.aiAdvanced),
        contains('Pro'),
      );
    });
  });

  group('entitlement service', () {
    test('free defaults expose basic AI only', () {
      const service = EntitlementService(EntitlementSnapshot.freeDefaults);
      expect(service.canUse(EntitlementKeys.aiBasic), isTrue);
      expect(service.canUse(EntitlementKeys.aiAdvanced), isFalse);
      expect(service.isSubscribed, isFalse);
      expect(service.lifecycle, SubscriptionLifecycle.none);
    });

    test('grace and billing retry still grant access', () {
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      final snapshot = EntitlementSnapshot.forTier(
        SubscriptionTier.plus,
        enabled: plus.entitlements,
        lifecycle: SubscriptionLifecycle.gracePeriod,
        verificationSource: EntitlementVerificationSource.serverVerified,
      );
      final service = EntitlementService(snapshot);
      expect(service.isSubscribed, isTrue);
      expect(service.isInGraceOrRetry, isTrue);
      expect(service.canUse(EntitlementKeys.analyticsAdvanced), isTrue);
    });

    test('expired locks premium without deleting keys from catalog knowledge', () {
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      final snapshot = EntitlementSnapshot.forTier(
        SubscriptionTier.plus,
        enabled: const {}, // access revoked — data retained elsewhere
        lifecycle: SubscriptionLifecycle.expired,
        willRenew: false,
        verificationSource: EntitlementVerificationSource.serverVerified,
      );
      final service = EntitlementService(snapshot);
      expect(service.canUse(EntitlementKeys.analyticsAdvanced), isFalse);
      expect(plus.includes(EntitlementKeys.analyticsAdvanced), isTrue);
      expect(service.lifecycle.grantsAccess, isFalse);
    });

    test('client never treats catalog preview as authoritative', () {
      expect(
        EntitlementVerificationSource.catalogPreview.isAuthoritative,
        isFalse,
      );
      expect(
        EntitlementVerificationSource.sandboxPreview.isAuthoritative,
        isFalse,
      );
      expect(
        EntitlementVerificationSource.serverVerified.isAuthoritative,
        isTrue,
      );
    });

    test('snapshot parse round-trip preserves keys; fromJson strips paid', () {
      final plus = SubscriptionCatalog.standard.productForTier(SubscriptionTier.plus);
      final original = EntitlementSnapshot.forTier(
        SubscriptionTier.plus,
        enabled: plus.entitlements,
        productId: plus.id,
        renewsAt: DateTime.utc(2026, 9, 1),
        expiresAt: DateTime.utc(2026, 9, 1),
        verificationSource: EntitlementVerificationSource.sandboxPreview,
      );
      final trusted = EntitlementSnapshot.parse(original.toJson());
      expect(trusted.tier, SubscriptionTier.plus);
      expect(trusted.enabled, plus.entitlements);

      final fromDisk = EntitlementSnapshot.fromJson(original.toJson());
      expect(fromDisk.tier, SubscriptionTier.free);
      expect(
        fromDisk.verificationSource,
        EntitlementVerificationSource.localCacheUntrusted,
      );
      expect(fromDisk.canUse(EntitlementKeys.analyticsAdvanced), isFalse);
      expect(fromDisk.productId, plus.id);
    });
  });

  group('billing stub', () {
    test('unsupported platform refuses live purchase grants', () async {
      const billing = UnsupportedBillingPlatform();
      expect(await billing.isAvailable, isFalse);
      final purchase = await billing.purchase('vytal.plus.monthly');
      expect(purchase.ok, isFalse);
      expect(purchase.requiresServerVerification, isTrue);
      final restore = await billing.restorePurchases();
      expect(restore.ok, isFalse);
    });
  });
}
