import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/fitness_hub_models.dart';
import 'fitness_repositories.dart';
import 'local_fitness_sync.dart';

const _calendarKey = 'vytal.fitness.calendar.v1';
const _savedGymsKey = 'vytal.fitness.saved_gyms.v1';
const _homeGymKey = 'vytal.fitness.home_gym.v1';
const _enrollmentsKey = 'vytal.fitness.plan_enrollments.v1';
const _photosKey = 'vytal.fitness.progress_photos.v1';
const _gymCacheKey = 'vytal.fitness.gym_cache.v1';

class LocalFitnessCalendarRepository implements FitnessCalendarRepository {
  @override
  Future<List<FitnessCalendarEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_calendarKey);
    if (raw == null) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(FitnessCalendarEvent.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveEvents(List<FitnessCalendarEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _calendarKey,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }
}

class LocalSavedGymRepository implements SavedGymRepository {
  @override
  Future<List<SavedGym>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedGymsKey);
    if (raw == null) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(SavedGym.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<SavedGym> gyms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedGymsKey,
      jsonEncode(gyms.map((e) => e.toJson()).toList()),
    );
  }
}

class LocalHomeGymRepository implements HomeGymRepository {
  @override
  Future<HomeGymProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_homeGymKey);
    if (raw == null) return const HomeGymProfile();
    try {
      return HomeGymProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const HomeGymProfile();
    }
  }

  @override
  Future<void> save(HomeGymProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homeGymKey, jsonEncode(profile.toJson()));
  }
}

class LocalPlanEnrollmentRepository implements PlanEnrollmentRepository {
  @override
  Future<List<PlanEnrollment>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_enrollmentsKey);
    if (raw == null) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(PlanEnrollment.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<PlanEnrollment> enrollments) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _enrollmentsKey,
      jsonEncode(enrollments.map((e) => e.toJson()).toList()),
    );
  }
}

class LocalProgressPhotoRepository implements ProgressPhotoRepository {
  @override
  Future<List<ProgressPhoto>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_photosKey);
    if (raw == null) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(ProgressPhoto.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<ProgressPhoto> photos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _photosKey,
      jsonEncode(photos.map((e) => e.toJson()).toList()),
    );
  }
}

/// TTL cache for nearby gym queries — prevents map-jitter refetch storms.
class GymQueryCache {
  static Future<List<GymPlace>?> read({
    required String cacheKey,
    Duration ttl = const Duration(minutes: 12),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_gymCacheKey.$cacheKey');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse(map['at'] as String? ?? '');
      if (at == null || DateTime.now().toUtc().difference(at) > ttl) {
        return null;
      }
      final list = (map['places'] as List).cast<Map<String, dynamic>>();
      return list.map(GymPlace.fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String cacheKey, List<GymPlace> places) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_gymCacheKey.$cacheKey',
      jsonEncode({
        'at': DateTime.now().toUtc().toIso8601String(),
        'places': places.map((e) => e.toJson()).toList(),
      }),
    );
  }
}

final fitnessCalendarRepositoryProvider =
    Provider<FitnessCalendarRepository>((ref) {
  return LocalFitnessCalendarRepository();
});

final savedGymRepositoryProvider = Provider<SavedGymRepository>((ref) {
  return LocalSavedGymRepository();
});

final homeGymRepositoryProvider = Provider<HomeGymRepository>((ref) {
  return LocalHomeGymRepository();
});

final planEnrollmentRepositoryProvider =
    Provider<PlanEnrollmentRepository>((ref) {
  return LocalPlanEnrollmentRepository();
});

final progressPhotoRepositoryProvider =
    Provider<ProgressPhotoRepository>((ref) {
  return LocalProgressPhotoRepository();
});

final fitnessSyncPortProvider = Provider<FitnessSyncPort>((ref) {
  return LocalQueuedFitnessSyncPort();
});
