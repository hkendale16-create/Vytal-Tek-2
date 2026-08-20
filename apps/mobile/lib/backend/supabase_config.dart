import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Vytal Tek Supabase project (dedicated — not FirstVue).
abstract final class VytalSupabaseConfig {
  static const projectUrl = String.fromEnvironment(
    'VYTAL_SUPABASE_URL',
    defaultValue: 'https://sdeifrzdkiiexawwzfvb.supabase.co',
  );

  /// Legacy anon JWT — required by supabase_flutter Auth.
  static const anonKey = String.fromEnvironment(
    'VYTAL_SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNkZWlmcnpka2lpZXhhd3d6ZnZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5Mzg1MDMsImV4cCI6MjEwMjUxNDUwM30.dAT1SrFRzqPK4vsDD4Bl4qQp_D9h8B3NP-G7Ay8GHN4',
  );

  /// Modern publishable key — used as apikey header for Edge Functions.
  static const publishableKey = String.fromEnvironment(
    'VYTAL_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_0Afaq57w4OzpNTGVVV3o4A_EvNk7COE',
  );

  static const verifyEntitlementPath = '/functions/v1/verify-entitlement';
  static const entitlementLifecyclePath = '/functions/v1/entitlement-lifecycle';
  static const fitnessSyncPath = '/functions/v1/fitness-sync';
  static const marketplacePath = '/functions/v1/marketplace-checkout';
  static const gymPartnerPath = '/functions/v1/gym-partner';

  static Uri get verifyEntitlementUri =>
      Uri.parse('$projectUrl$verifyEntitlementPath');
  static Uri get entitlementLifecycleUri =>
      Uri.parse('$projectUrl$entitlementLifecyclePath');
  static Uri get fitnessSyncUri => Uri.parse('$projectUrl$fitnessSyncPath');
  static Uri get marketplaceUri => Uri.parse('$projectUrl$marketplacePath');
  static Uri get gymPartnerUri => Uri.parse('$projectUrl$gymPartnerPath');

  static bool get isReady {
    try {
      // ignore: unnecessary_statements
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> ensureInitialized() async {
    if (isReady) return;
    await Supabase.initialize(
      url: projectUrl,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Current access token for Edge Function calls — null when signed out.
final authAccessTokenProvider = Provider<String?>((ref) {
  ref.watch(authSessionProvider);
  return Supabase.instance.client.auth.currentSession?.accessToken;
});

final authSessionProvider = StreamProvider<Session?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((e) => e.session);
});

final authUserProvider = Provider<User?>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  return session?.user ?? Supabase.instance.client.auth.currentUser;
});

class AuthController {
  AuthController(this._client);

  final SupabaseClient _client;

  bool get isSignedIn => _client.auth.currentSession != null;

  String? get accessToken => _client.auth.currentSession?.accessToken;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(supabaseClientProvider));
});
