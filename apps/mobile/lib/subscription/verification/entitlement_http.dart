import 'dart:convert';

import 'package:http/http.dart' as http;

/// Default JSON POST used by [HttpEntitlementVerifier] in production builds.
Future<Map<String, dynamic>> defaultEntitlementHttpPost(
  Uri url,
  Map<String, dynamic> body,
) async {
  final response = await http
      .post(
        url,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError(
      'Entitlement API HTTP ${response.statusCode}: ${response.body}',
    );
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Entitlement API returned non-object JSON.');
  }
  return decoded;
}
