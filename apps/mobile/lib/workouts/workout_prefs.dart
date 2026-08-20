import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _autoRestKey = 'vytal.workouts.auto_rest.v1';
const _defaultRestKey = 'vytal.workouts.default_rest_sec.v1';

class WorkoutPrefs {
  const WorkoutPrefs({
    this.autoRestEnabled = true,
    this.defaultRestSeconds = 90,
  });

  final bool autoRestEnabled;
  final int defaultRestSeconds;

  WorkoutPrefs copyWith({
    bool? autoRestEnabled,
    int? defaultRestSeconds,
  }) {
    return WorkoutPrefs(
      autoRestEnabled: autoRestEnabled ?? this.autoRestEnabled,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
    );
  }
}

final workoutPrefsProvider =
    StateNotifierProvider<WorkoutPrefsController, WorkoutPrefs>((ref) {
  return WorkoutPrefsController()..restore();
});

class WorkoutPrefsController extends StateNotifier<WorkoutPrefs> {
  WorkoutPrefsController() : super(const WorkoutPrefs());

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    state = WorkoutPrefs(
      autoRestEnabled: prefs.getBool(_autoRestKey) ?? true,
      defaultRestSeconds: prefs.getInt(_defaultRestKey)?.clamp(5, 600) ?? 90,
    );
  }

  Future<void> setAutoRestEnabled(bool enabled) async {
    state = state.copyWith(autoRestEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoRestKey, enabled);
  }

  Future<void> setDefaultRestSeconds(int seconds) async {
    final clamped = seconds.clamp(5, 600);
    state = state.copyWith(defaultRestSeconds: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_defaultRestKey, clamped);
  }
}
