import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../backend/supabase_config.dart';
import 'entitlement_api_config.dart';

/// Default JSON POST used by [HttpEntitlementVerifier] in production builds.
///
/// Uses the signed-in user JWT when available. Anonymous publishable/anon
/// bearer alone cannot receive premium grants (server requireUserId).
Future<Map<String, dynamic>> defaultEntitlementHttpPost(
  Uri url,
  Map<String, dynamic> body,
) async {
  final session = VytalSupabaseConfig.isReady
      ? Supabase.instance.client.auth.currentSession
      : null;
  final userJwt = session?.accessToken;
  final apikey = EntitlementApiConfig.publishableKey.isNotEmpty
      ? EntitlementApiConfig.publishableKey
      : VytalSupabaseConfig.anonKey;
  final bearer = (userJwt != null && userJwt.isNotEmpty)
      ? userJwt
      : VytalSupabaseConfig.anonKey;

  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'apikey': apikey,
    'Authorization': 'Bearer $bearer',
  };

  final response = await http
      .post(url, headers: headers, body: jsonEncode(body))
      .timeout(const Duration(seconds: 20));

  final decoded = jsonDecode(response.body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }

  throw StateError(
    'Entitlement API HTTP ${response.statusCode}: ${response.body}',
  );
}
