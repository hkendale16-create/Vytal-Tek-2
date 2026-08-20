import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/workout_models.dart';
import 'fitness_repositories.dart';

const fitnessSyncQueueKey = 'vytal.fitness.sync_queue.v1';

/// Local-first sync queue — persists outbound workout mirrors until a future
/// cloud port can flush them. Never claims cloud delivery succeeded.
class LocalQueuedFitnessSyncPort implements FitnessSyncPort {
  LocalQueuedFitnessSyncPort();

  @override
  Future<void> enqueueWorkout(WorkoutHistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(fitnessSyncQueueKey);
    final list = <Map<String, dynamic>>[];
    if (raw != null) {
      try {
        list.addAll(
          (jsonDecode(raw) as List).cast<Map>().map(
                (e) => Map<String, dynamic>.from(e),
              ),
        );
      } catch (_) {
        // Reset corrupt queue.
      }
    }
    list.removeWhere((e) => e['id'] == entry.id);
    list.add({
      'id': entry.id,
      'queuedAt': DateTime.now().toUtc().toIso8601String(),
      'kind': 'workout_completed',
      'payload': entry.toJson(),
    });
    // Cap queue so offline devices don't grow unbounded.
    final trimmed = list.length > 100 ? list.sublist(list.length - 100) : list;
    await prefs.setString(fitnessSyncQueueKey, jsonEncode(trimmed));
  }

  @override
  Future<void> flush() async {
    // No remote endpoint yet — keep the queue for a future uploader.
  }

  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(fitnessSyncQueueKey);
    if (raw == null) return 0;
    try {
      return (jsonDecode(raw) as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> peek() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(fitnessSyncQueueKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
