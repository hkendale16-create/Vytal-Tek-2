import 'package:flutter_test/flutter_test.dart';
import 'package:vytal_tek/subscription/legal_links.dart';
import 'package:vytal_tek/subscription/verification/entitlement_api_config.dart';
import 'package:vytal_tek/subscription/verification/entitlement_verifier.dart';
import 'package:vytal_tek/subscription/entitlement_service.dart';

void main() {
  group('Phase G marketplace client', () {
    test('legal URLs are absolute https', () {
      expect(VytalLegalLinks.privacyUri.isScheme('https'), isTrue);
      expect(VytalLegalLinks.termsUri.isScheme('https'), isTrue);
      expect(VytalLegalLinks.privacyUrl, contains('privacy'));
      expect(VytalLegalLinks.termsUrl, contains('terms'));
    });

    test('disclosure mentions auto-renew and cancel path', () {
      final body = SubscriptionDisclosure.body.toLowerCase();
      expect(body, contains('auto-renew'));
      expect(body, contains('cancel'));
      expect(body, contains('app store'));
      expect(body, contains('play'));
      expect(body, contains('server verification'));
    });

    test('unconfigured entitlement API reports not configured', () {
      final config = EntitlementApiConfig.fromEnvironment();
      // Without dart-define in tests, endpoint is null.
      expect(config.isConfigured, isFalse);
    });

    test('HttpEntitlementVerifier fails closed without postJson', () async {
      final verifier = HttpEntitlementVerifier(
        endpoint: Uri.parse('https://example.test/verify'),
      );
      final result = await verifier.verify(
        PurchaseReceipt(
          productId: 'vytal.plus.monthly',
          platform: BillingPlatformKind.appleStoreKit,
          purchaseId: 'x',
          verificationData: 'store.token.should-not-grant',
          transactionDate: DateTime.now().toUtc(),
        ),
      );
      expect(result.ok, isFalse);
      expect(result.snapshot, isNull);
      expect(result.message.toLowerCase(), contains('not configured'));
    });
  });
}
