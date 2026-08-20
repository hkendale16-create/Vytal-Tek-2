import '../../backend/supabase_config.dart';
import '../../backend/vytal_backend_client.dart';
import '../../domain/models/ecosystem_future.dart';

/// Server-backed marketplace + gym partner calls.
class EcosystemBackend {
  EcosystemBackend({VytalBackendClient? client})
      : _client = client ?? VytalBackendClient();

  final VytalBackendClient _client;

  Future<Map<String, dynamic>> expressInterest(String programId) {
    return _client.post(VytalSupabaseConfig.marketplaceUri, {
      'action': 'interest',
      'programId': programId,
    });
  }

  Future<Map<String, dynamic>> checkoutProgram({
    required String programId,
    Map<String, dynamic>? receipt,
  }) {
    return _client.post(VytalSupabaseConfig.marketplaceUri, {
      'action': 'checkout',
      'programId': programId,
      if (receipt != null) 'receipt': receipt,
      'platform': receipt?['platform'] ?? 'sandbox',
    });
  }

  Future<Map<String, dynamic>> requestGymClaim({
    required String placeId,
    required String businessName,
    String? contactEmail,
  }) {
    return _client.post(VytalSupabaseConfig.gymPartnerUri, {
      'action': 'claim',
      'placeId': placeId,
      'businessName': businessName,
      if (contactEmail != null) 'contactEmail': contactEmail,
    });
  }

  Future<List<GymBusinessProfile>> fetchMyClaims() async {
    final json = await _client.post(VytalSupabaseConfig.gymPartnerUri, {
      'action': 'my_claims',
    });
    final claims = (json['claims'] as List?) ?? const [];
    return claims.map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return GymBusinessProfile(
        placeId: m['place_id'] as String? ?? '',
        businessName: m['business_name'] as String? ?? 'Gym',
        contactEmail: m['contact_email'] as String?,
        verified: m['verified'] as bool? ?? false,
        partner: m['partner'] as bool? ?? false,
        promoted: m['promoted'] as bool? ?? false,
        offerLabels:
            (m['offer_labels'] as List?)?.cast<String>() ?? const [],
        claimStatus: GymClaimStatusX.fromJson(m['status'] as String?),
        requestedAt: DateTime.tryParse(m['requested_at'] as String? ?? ''),
      );
    }).toList();
  }

  Future<Map<String, dynamic>> fetchOffers({List<String> placeIds = const []}) {
    final uri = placeIds.isEmpty
        ? VytalSupabaseConfig.gymPartnerUri
        : VytalSupabaseConfig.gymPartnerUri.replace(
            queryParameters: {'placeIds': placeIds.join(',')},
          );
    return _client.get(uri, requireUser: false);
  }
}
