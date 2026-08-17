/// Legal + marketplace disclosure URLs for Phase G store review.
///
/// Override at build time:
/// `--dart-define=VYTAL_PRIVACY_URL=https://…`
/// `--dart-define=VYTAL_TERMS_URL=https://…`
class VytalLegalLinks {
  const VytalLegalLinks._();

  static const privacyUrl = String.fromEnvironment(
    'VYTAL_PRIVACY_URL',
    defaultValue: 'https://vytaltek.com/privacy',
  );

  static const termsUrl = String.fromEnvironment(
    'VYTAL_TERMS_URL',
    defaultValue: 'https://vytaltek.com/terms',
  );

  static Uri get privacyUri => Uri.parse(privacyUrl);
  static Uri get termsUri => Uri.parse(termsUrl);
}

/// App Store / Play required subscription disclosure (auto-renew + cancel).
abstract final class SubscriptionDisclosure {
  static const title = 'Subscription details';

  static const body =
      'Vytal Plus and Vytal Pro are auto-renewable subscriptions billed through '
      'Apple App Store or Google Play. Payment is charged to your store account '
      'at confirmation. Subscriptions renew automatically unless canceled at '
      'least 24 hours before the end of the current period. Manage or cancel '
      'anytime in your App Store or Play subscription settings — Vytal never '
      'hides the platform cancel path. Premium features unlock only after Vytal '
      'server verification of a valid purchase.';

  static const shortFooter =
      'Auto-renews until canceled in App Store / Play. '
      'Privacy Policy and Terms apply.';
}
