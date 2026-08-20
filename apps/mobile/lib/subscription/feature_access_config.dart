import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/entitlements.dart';

const _featureConfigKey = 'vytal.feature_access_config.v1';

/// Remote-configurable feature availability.
///
/// Cached locally for UX experiments (move feature between tiers, AI limits).
/// **Never grants paid access by itself** — [EntitlementSecurity] + server
/// verification remain authoritative.
class FeatureAccessConfig {
  const FeatureAccessConfig({
    this.enabled = const {},
    this.tierOverrides = const {},
    this.aiCoachDailyLimitFree = 20,
    this.version = 1,
    this.source = FeatureConfigSource.bundledDefaults,
  });

  /// When a key maps to false, the feature is remotely disabled for everyone.
  final Map<String, bool> enabled;

  /// Optional override: entitlement key → lowest subscription tier id name.
  final Map<String, String> tierOverrides;

  final int aiCoachDailyLimitFree;
  final int version;
  final FeatureConfigSource source;

  bool isFeatureEnabled(String key) => enabled[key] ?? true;

  /// Returns null to fall back to [SubscriptionCatalog.lowestTierFor].
  Set<SubscriptionTier>? requiredTierFor(String key) {
    final raw = tierOverrides[key];
    if (raw == null || raw.isEmpty) return null;
    final tier = SubscriptionTier.values.where((t) => t.name == raw);
    if (tier.isEmpty) return null;
    return {tier.first};
  }

  FeatureAccessConfig copyWith({
    Map<String, bool>? enabled,
    Map<String, String>? tierOverrides,
    int? aiCoachDailyLimitFree,
    int? version,
    FeatureConfigSource? source,
  }) {
    return FeatureAccessConfig(
      enabled: enabled ?? this.enabled,
      tierOverrides: tierOverrides ?? this.tierOverrides,
      aiCoachDailyLimitFree:
          aiCoachDailyLimitFree ?? this.aiCoachDailyLimitFree,
      version: version ?? this.version,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'tierOverrides': tierOverrides,
        'aiCoachDailyLimitFree': aiCoachDailyLimitFree,
        'version': version,
        'source': source.name,
      };

  factory FeatureAccessConfig.fromJson(Map<String, dynamic> json) {
    final enabledRaw = json['enabled'];
    final tiersRaw = json['tierOverrides'];
    return FeatureAccessConfig(
      enabled: enabledRaw is Map
          ? enabledRaw.map((k, v) => MapEntry(k.toString(), v == true))
          : const {},
      tierOverrides: tiersRaw is Map
          ? tiersRaw.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      aiCoachDailyLimitFree: json['aiCoachDailyLimitFree'] as int? ?? 20,
      version: json['version'] as int? ?? 1,
      source: FeatureConfigSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => FeatureConfigSource.remoteCache,
      ),
    );
  }

  /// Bundled defaults matching [docs/MONETIZATION_ARCHITECTURE.md].
  static const bundled = FeatureAccessConfig(
    enabled: {
      EntitlementKeys.gymsNearby: true,
      EntitlementKeys.exercisesLibrary: true,
      EntitlementKeys.calendarBasic: true,
      EntitlementKeys.plansBasic: true,
      EntitlementKeys.progressBasic: true,
      EntitlementKeys.aiWorkoutBuilder: true,
      EntitlementKeys.plansAdvanced: true,
      EntitlementKeys.progressAdvanced: true,
    },
    // Empty overrides → catalog is source of truth for tier placement.
    tierOverrides: {},
    aiCoachDailyLimitFree: 20,
    version: 1,
    source: FeatureConfigSource.bundledDefaults,
  );
}

enum FeatureConfigSource { bundledDefaults, remoteCache, remoteLive }

class FeatureAccessConfigController extends StateNotifier<FeatureAccessConfig> {
  FeatureAccessConfigController() : super(FeatureAccessConfig.bundled);

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_featureConfigKey);
    if (raw == null) return;
    try {
      state = FeatureAccessConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      state = FeatureAccessConfig.bundled;
    }
  }

  /// Apply a remote blob after transport fetch (caller verifies signature later).
  Future<void> applyRemote(Map<String, dynamic> json) async {
    final next = FeatureAccessConfig.fromJson({
      ...json,
      'source': FeatureConfigSource.remoteCache.name,
    });
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_featureConfigKey, jsonEncode(next.toJson()));
  }

  Future<void> resetToBundled() async {
    state = FeatureAccessConfig.bundled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_featureConfigKey);
  }
}
