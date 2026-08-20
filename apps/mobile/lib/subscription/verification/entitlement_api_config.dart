import '../../backend/supabase_config.dart';

/// Production entitlement API configuration (Phase G + backend platform).
///
/// Build with:
/// `--dart-define=VYTAL_ENTITLEMENT_API=https://sdeifrzdkiiexawwzfvb.supabase.co/functions/v1/verify-entitlement`
class EntitlementApiConfig {
  const EntitlementApiConfig({
    required this.endpoint,
    this.lifecycleEndpoint,
  });

  final Uri? endpoint;
  final Uri? lifecycleEndpoint;

  bool get isConfigured => endpoint != null;

  /// Public publishable key — safe in the client. Never a service-role key.
  static const publishableKey = String.fromEnvironment(
    'VYTAL_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_0Afaq57w4OzpNTGVVV3o4A_EvNk7COE',
  );

  static const defaultVerifyUrl =
      'https://sdeifrzdkiiexawwzfvb.supabase.co/functions/v1/verify-entitlement';

  static final defaultLifecycleUri = VytalSupabaseConfig.entitlementLifecycleUri;

  /// Reads compile-time defines. Empty string → unconfigured (debug uses mock).
  factory EntitlementApiConfig.fromEnvironment() {
    const raw = String.fromEnvironment('VYTAL_ENTITLEMENT_API');
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const EntitlementApiConfig(endpoint: null);
    }
    return EntitlementApiConfig(
      endpoint: Uri.parse(trimmed),
      lifecycleEndpoint: defaultLifecycleUri,
    );
  }
}
