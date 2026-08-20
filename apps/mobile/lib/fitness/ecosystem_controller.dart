import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/ecosystem_future.dart';

const _gymClaimsKey = 'vytal.ecosystem.gym_claims.v1';
const _savedProgramsKey = 'vytal.ecosystem.saved_programs.v1';
const _interestKey = 'vytal.ecosystem.trainer_interest.v1';

class EcosystemState {
  const EcosystemState({
    this.claims = const {},
    this.savedProgramIds = const [],
    this.interestProgramIds = const [],
    this.ready = false,
  });

  final Map<String, GymBusinessProfile> claims;
  final List<String> savedProgramIds;
  final List<String> interestProgramIds;
  final bool ready;

  EcosystemState copyWith({
    Map<String, GymBusinessProfile>? claims,
    List<String>? savedProgramIds,
    List<String>? interestProgramIds,
    bool? ready,
  }) {
    return EcosystemState(
      claims: claims ?? this.claims,
      savedProgramIds: savedProgramIds ?? this.savedProgramIds,
      interestProgramIds: interestProgramIds ?? this.interestProgramIds,
      ready: ready ?? this.ready,
    );
  }

  GymBusinessProfile? claimFor(String placeId) => claims[placeId];
}

final ecosystemProvider =
    StateNotifierProvider<EcosystemController, EcosystemState>((ref) {
  return EcosystemController()..restore();
});

class EcosystemController extends StateNotifier<EcosystemState> {
  EcosystemController() : super(const EcosystemState());

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final claimsRaw = prefs.getString(_gymClaimsKey);
    final savedRaw = prefs.getString(_savedProgramsKey);
    final interestRaw = prefs.getString(_interestKey);
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
      savedProgramIds: _decodeIds(savedRaw),
      interestProgramIds: _decodeIds(interestRaw),
      ready: true,
    );
  }

  List<String> _decodeIds(String? raw) {
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  Future<void> requestGymClaim({
    required String placeId,
    required String businessName,
    String? contactEmail,
  }) async {
    final next = Map<String, GymBusinessProfile>.from(state.claims);
    next[placeId] = GymBusinessProfile(
      placeId: placeId,
      businessName: businessName.trim().isEmpty ? 'Gym' : businessName.trim(),
      contactEmail: contactEmail?.trim().isEmpty == true
          ? null
          : contactEmail?.trim(),
      claimStatus: GymClaimStatus.pending,
      requestedAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(claims: next);
    await _persistClaims();
  }

  /// Local demo approval for partner review — not a live marketplace decision.
  Future<void> markClaimApproved(String placeId, {bool partner = true}) async {
    final existing = state.claims[placeId];
    if (existing == null) return;
    final next = Map<String, GymBusinessProfile>.from(state.claims);
    next[placeId] = existing.copyWith(
      claimStatus: GymClaimStatus.approved,
      verified: true,
      partner: partner,
    );
    state = state.copyWith(claims: next);
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
    if (state.interestProgramIds.contains(programId)) return;
    state = state.copyWith(
      interestProgramIds: [...state.interestProgramIds, programId],
    );
    await _persistIds(_interestKey, state.interestProgramIds);
  }

  Future<void> _persistClaims() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _gymClaimsKey,
      jsonEncode(state.claims.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  Future<void> _persistIds(String key, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(ids));
  }
}
