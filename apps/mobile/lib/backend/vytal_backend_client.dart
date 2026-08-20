import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Authenticated JSON POST/GET for Vytal Edge Functions.
///
/// Prefer the signed-in user JWT. Never send the service role key from the app.
class VytalBackendClient {
  VytalBackendClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Map<String, String> _headers({bool requireUser = true}) {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    if (requireUser && (token == null || token.isEmpty)) {
      throw StateError('Sign in required for this backend call');
    }
    final bearer = (token != null && token.isNotEmpty)
        ? token
        : VytalSupabaseConfig.anonKey;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'apikey': VytalSupabaseConfig.anonKey,
      'Authorization': 'Bearer $bearer',
    };
  }

  Future<Map<String, dynamic>> post(
    Uri url,
    Map<String, dynamic> body, {
    bool requireUser = true,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = {
      ..._headers(requireUser: requireUser),
      ...?extraHeaders,
    };
    final response = await _http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    return _decode(response);
  }

  Future<Map<String, dynamic>> get(
    Uri url, {
    bool requireUser = false,
  }) async {
    final response = await _http
        .get(url, headers: _headers(requireUser: requireUser))
        .timeout(const Duration(seconds: 25));
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      if (response.statusCode >= 400 && decoded['ok'] != true) {
        final message = decoded['message'] as String? ??
            'Backend HTTP ${response.statusCode}';
        throw StateError(message);
      }
      return decoded;
    }
    throw StateError(
      'Backend HTTP ${response.statusCode}: ${response.body}',
    );
  }
}
