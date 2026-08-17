/// Production entitlement API configuration (Phase G).
///
/// Build with:
/// `--dart-define=VYTAL_ENTITLEMENT_API=https://<project>.supabase.co/functions/v1/verify-entitlement`
class EntitlementApiConfig {
  const EntitlementApiConfig({required this.endpoint});

  final Uri? endpoint;

  bool get isConfigured => endpoint != null;

  /// Reads compile-time defines. Empty string → unconfigured.
  factory EntitlementApiConfig.fromEnvironment() {
    const raw = String.fromEnvironment('VYTAL_ENTITLEMENT_API');
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const EntitlementApiConfig(endpoint: null);
    }
    return EntitlementApiConfig(endpoint: Uri.parse(trimmed));
  }
}
