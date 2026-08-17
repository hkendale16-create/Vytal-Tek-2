import 'dart:convert';

import 'package:http/http.dart' as http;

import 'entitlement_api_config.dart';

/// Default JSON POST used by [HttpEntitlementVerifier] in production builds.
Future<Map<String, dynamic>> defaultEntitlementHttpPost(
  Uri url,
  Map<String, dynamic> body,
) async {
  final key = EntitlementApiConfig.publishableKey;
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (key.isNotEmpty) 'apikey': key,
    if (key.isNotEmpty) 'Authorization': 'Bearer $key',
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
