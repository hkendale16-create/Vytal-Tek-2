import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/workout_models.dart';

const activeWorkoutDraftKey = 'vytal.workouts.active_draft.v1';

/// Local draft so an in-gym session survives connectivity loss / process death.
class ActiveWorkoutDraft {
  const ActiveWorkoutDraft({
    required this.savedAt,
    required this.activityKind,
    required this.elapsedSeconds,
    required this.setLogs,
    this.routineId,
    this.routineName,
    this.notes = '',
    this.distanceMeters = 0,
  });

  final DateTime savedAt;
  final WorkoutActivityKind activityKind;
  final int elapsedSeconds;
  final List<WorkoutSetLog> setLogs;
  final String? routineId;
  final String? routineName;
  final String notes;
  final double distanceMeters;

  Map<String, dynamic> toJson() => {
        'savedAt': savedAt.toIso8601String(),
        'activityKind': activityKind.name,
        'elapsedSeconds': elapsedSeconds,
        'setLogs': setLogs.map((e) => e.toJson()).toList(),
        'routineId': routineId,
        'routineName': routineName,
        'notes': notes,
        'distanceMeters': distanceMeters,
      };

  factory ActiveWorkoutDraft.fromJson(Map<String, dynamic> json) =>
      ActiveWorkoutDraft(
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        activityKind: WorkoutActivityKind.fromJson(
          json['activityKind'] as String?,
        ),
        elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
        setLogs: ((json['setLogs'] as List?) ?? const [])
            .cast<Map>()
            .map((e) => WorkoutSetLog.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        routineId: json['routineId'] as String?,
        routineName: json['routineName'] as String?,
        notes: json['notes'] as String? ?? '',
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      );

  static Future<void> persist(ActiveWorkoutDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(activeWorkoutDraftKey, jsonEncode(draft.toJson()));
  }

  static Future<ActiveWorkoutDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(activeWorkoutDraftKey);
    if (raw == null) return null;
    try {
      return ActiveWorkoutDraft.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(activeWorkoutDraftKey);
  }
}
