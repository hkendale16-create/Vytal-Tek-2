import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Privacy-respecting conversion / funnel analytics.
///
/// Never log raw vitals, SpO2, HR samples, or clinical values here.
abstract final class ConversionEvents {
  static const workoutStarted = 'workout_started';
  static const workoutCompleted = 'workout_completed';
  static const planViewed = 'plan_viewed';
  static const gymSearched = 'gym_searched';
  static const gymSaved = 'gym_saved';
  static const coachOpened = 'coach_opened';
  static const proFeatureViewed = 'pro_feature_viewed';
  static const upgradeViewed = 'upgrade_viewed';
  static const trialStarted = 'trial_started';
  static const subscriptionStarted = 'subscription_started';
  static const deviceConnectStarted = 'device_connect_started';
  static const deviceConnected = 'device_connected';
  static const deviceExploreViewed = 'device_explore_viewed';

  static const allowed = <String>{
    workoutStarted,
    workoutCompleted,
    planViewed,
    gymSearched,
    gymSaved,
    coachOpened,
    proFeatureViewed,
    upgradeViewed,
    trialStarted,
    subscriptionStarted,
    deviceConnectStarted,
    deviceConnected,
    deviceExploreViewed,
  };
}

/// Local queue — portable to a future analytics backend without UI changes.
abstract class ConversionAnalytics {
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  });

  Future<List<Map<String, dynamic>>> drain();
}

class LocalConversionAnalytics implements ConversionAnalytics {
  LocalConversionAnalytics();

  static const _key = 'vytal.analytics.conversion_queue.v1';
  static const _max = 200;

  /// Blocked property keys — health measurements must never enter this queue.
  static const _blockedPropertyKeys = {
    'heartRate',
    'hr',
    'hrv',
    'spo2',
    'temperature',
    'sleepStages',
    'rawReading',
    'biometric',
  };

  @override
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  }) async {
    if (!ConversionEvents.allowed.contains(event)) return;
    final safe = <String, Object?>{};
    for (final entry in properties.entries) {
      if (_blockedPropertyKeys.contains(entry.key)) continue;
      final value = entry.value;
      if (value == null ||
          value is num ||
          value is bool ||
          value is String) {
        safe[entry.key] = value;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    final list = <Map<String, dynamic>>[];
    if (existing != null) {
      try {
        list.addAll(
          (jsonDecode(existing) as List).cast<Map<String, dynamic>>(),
        );
      } catch (_) {}
    }
    list.add({
      'event': event,
      'at': DateTime.now().toUtc().toIso8601String(),
      'properties': safe,
    });
    while (list.length > _max) {
      list.removeAt(0);
    }
    await prefs.setString(_key, jsonEncode(list));
  }

  @override
  Future<List<Map<String, dynamic>>> drain() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    await prefs.remove(_key);
    if (existing == null) return const [];
    try {
      return (jsonDecode(existing) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }
}

final conversionAnalyticsProvider = Provider<ConversionAnalytics>((ref) {
  return LocalConversionAnalytics();
});
