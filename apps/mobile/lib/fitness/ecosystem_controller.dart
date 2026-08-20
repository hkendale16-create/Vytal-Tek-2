import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/ecosystem_backend.dart';
import '../domain/models/ecosystem_future.dart';

const _gymClaimsKey = 'vytal.ecosystem.gym_claims.v1';
const _savedProgramsKey = 'vytal.ecosystem.saved_programs.v1';
const _interestKey = 'vytal.ecosystem.trainer_interest.v1';
const _purchasedKey = 'vytal.ecosystem.purchased_programs.v1';

class EcosystemState {
  const EcosystemState({
    this.claims = const {},
    this.savedProgramIds = const [],
    this.interestProgramIds = const [],
    this.purchasedProgramIds = const [],
    this.sponsoredPlaceIds = const [],
    this.ready = false,
    this.lastError,
  });

  final Map<String, GymBusinessProfile> claims;
  final List<String> savedProgramIds;
  final List<String> interestProgramIds;
  final List<String> purchasedProgramIds;
  final List<String> sponsoredPlaceIds;
  final bool ready;
  final String? lastError;

  EcosystemState copyWith({
    Map<String, GymBusinessProfile>? claims,
    List<String>? savedProgramIds,
    List<String>? interestProgramIds,
    List<String>? purchasedProgramIds,
    List<String>? sponsoredPlaceIds,
    bool? ready,
    String? lastError,
    bool clearError = false,
  }) {
    return EcosystemState(
      claims: claims ?? this.claims,
      savedProgramIds: savedProgramIds ?? this.savedProgramIds,
      interestProgramIds: interestProgramIds ?? this.interestProgramIds,
      purchasedProgramIds: purchasedProgramIds ?? this.purchasedProgramIds,
      sponsoredPlaceIds: sponsoredPlaceIds ?? this.sponsoredPlaceIds,
      ready: ready ?? this.ready,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  GymBusinessProfile? claimFor(String placeId) => claims[placeId];

  bool isSponsored(String placeId) => sponsoredPlaceIds.contains(placeId);
}

final ecosystemBackendProvider = Provider<EcosystemBackend>((ref) {
  return EcosystemBackend();
});

final ecosystemProvider =
    StateNotifierProvider<EcosystemController, EcosystemState>((ref) {
  return EcosystemController(ref)..restore();
});

class EcosystemController extends StateNotifier<EcosystemState> {
  EcosystemController(this._ref) : super(const EcosystemState());

  final Ref _ref;

  EcosystemBackend get _backend => _ref.read(ecosystemBackendProvider);

  bool get _signedIn {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final claimsRaw = prefs.getString(_gymClaimsKey);
    final claims = <String, GymBusinessProfile>{};
    if (claimsRaw != null) {
      try {
        final map = jsonDecode(claimsRaw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          claims[entry.key] = GymBusinessProfile.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      } catch (_) {}
    }
    state = EcosystemState(
      claims: claims,
      savedProgramIds: _decodeIds(prefs.getString(_savedProgramsKey)),
      interestProgramIds: _decodeIds(prefs.getString(_interestKey)),
      purchasedProgramIds: _decodeIds(prefs.getString(_purchasedKey)),
      ready: true,
    );
    try {
      await refreshFromServer();
    } catch (_) {
      // Offline / Supabase not initialized in unit tests.
    }
  }

  List<String> _decodeIds(String? raw) {
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  Future<void> refreshFromServer() async {
    try {
      final offers = await _backend.fetchOffers();
      final sponsored = ((offers['sponsored'] as List?) ?? const [])
          .map((e) => (e as Map)['place_id'] as String?)
          .whereType<String>()
          .toList();
      var claims = state.claims;
      if (_signedIn) {
        final remote = await _backend.fetchMyClaims();
        if (remote.isNotEmpty) {
          claims = {
            for (final c in remote) c.placeId: c.copyWith(
              promoted: c.promoted || sponsored.contains(c.placeId),
            ),
          };
          await _persistClaimsMap(claims);
        }
      }
      state = state.copyWith(
        claims: claims,
        sponsoredPlaceIds: sponsored,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  Future<void> requestGymClaim({
    required String placeId,
    required String businessName,
    String? contactEmail,
  }) async {
    final local = GymBusinessProfile(
      placeId: placeId,
      businessName: businessName.trim().isEmpty ? 'Gym' : businessName.trim(),
      contactEmail: contactEmail?.trim().isEmpty == true
          ? null
          : contactEmail?.trim(),
      claimStatus: GymClaimStatus.pending,
      requestedAt: DateTime.now().toUtc(),
    );
    final next = Map<String, GymBusinessProfile>.from(state.claims);
    next[placeId] = local;
    state = state.copyWith(claims: next, clearError: true);
    await _persistClaims();

    if (!_signedIn) {
      state = state.copyWith(
        lastError: 'Claim saved locally — sign in to submit for partner review.',
      );
      return;
    }
    try {
      final res = await _backend.requestGymClaim(
        placeId: placeId,
        businessName: local.businessName,
        contactEmail: local.contactEmail,
      );
      final claim = res['claim'];
      if (claim is Map) {
        final remote = GymBusinessProfile(
          placeId: claim['place_id'] as String? ?? placeId,
          businessName: claim['business_name'] as String? ?? local.businessName,
          contactEmail: claim['contact_email'] as String?,
          claimStatus: GymClaimStatusX.fromJson(claim['status'] as String?),
          verified: claim['verified'] as bool? ?? false,
          partner: claim['partner'] as bool? ?? false,
          promoted: claim['promoted'] as bool? ?? false,
          requestedAt: DateTime.tryParse(claim['requested_at'] as String? ?? '') ??
              local.requestedAt,
        );
        next[placeId] = remote;
        state = state.copyWith(claims: next, clearError: true);
        await _persistClaims();
      }
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  /// Local-only demo approval when offline. Server partner review is authoritative.
  Future<void> markClaimApproved(String placeId, {bool partner = true}) async {
    final existing = state.claims[placeId];
    if (existing == null) return;
    final next = Map<String, GymBusinessProfile>.from(state.claims);
    next[placeId] = existing.copyWith(
      claimStatus: GymClaimStatus.approved,
      verified: true,
      partner: partner,
    );
    state = state.copyWith(
      claims: next,
      lastError:
          'Local demo approval only — partner pipeline review is authoritative when signed in.',
    );
    await _persistClaims();
  }

  Future<void> saveProgram(String programId) async {
    if (state.savedProgramIds.contains(programId)) return;
    state = state.copyWith(
      savedProgramIds: [...state.savedProgramIds, programId],
    );
    await _persistIds(_savedProgramsKey, state.savedProgramIds);
  }

  Future<void> expressInterest(String programId) async {
    if (!state.interestProgramIds.contains(programId)) {
      state = state.copyWith(
        interestProgramIds: [...state.interestProgramIds, programId],
      );
      await _persistIds(_interestKey, state.interestProgramIds);
    }
    if (!_signedIn) {
      state = state.copyWith(
        lastError: 'Interest saved locally — sign in to sync to marketplace.',
      );
      return;
    }
    try {
      await _backend.expressInterest(programId);
      state = state.copyWith(clearError: true);
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  Future<Map<String, dynamic>?> checkoutProgram(String programId) async {
    if (!_signedIn) {
      state = state.copyWith(
        lastError: 'Sign in required for marketplace checkout.',
      );
      return null;
    }
    final program = TrainerMarketplaceCatalog.featured
        .where((p) => p.id == programId)
        .firstOrNull;
    final paid = program?.advanced == true;
    try {
      final res = await _backend.checkoutProgram(
        programId: programId,
        receipt: paid
            ? {
                'platform': 'sandbox',
                'verificationData':
                    'sandbox.token.$programId.${DateTime.now().millisecondsSinceEpoch}',
                'productId': 'vytal.trainer.${programId.split('-').last}',
              }
            : null,
      );
      if (res['ok'] == true) {
        if (!state.purchasedProgramIds.contains(programId)) {
          state = state.copyWith(
            purchasedProgramIds: [...state.purchasedProgramIds, programId],
            clearError: true,
          );
          await _persistIds(_purchasedKey, state.purchasedProgramIds);
        }
      }
      return res;
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
      return null;
    }
  }

  Future<void> _persistClaims() async => _persistClaimsMap(state.claims);

  Future<void> _persistClaimsMap(Map<String, GymBusinessProfile> claims) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _gymClaimsKey,
      jsonEncode(claims.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  Future<void> _persistIds(String key, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(ids));
  }
}

extension _FirstOrNullEco<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
