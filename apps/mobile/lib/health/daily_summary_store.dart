import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/daily_health_summary.dart';
import '../domain/models/data_provenance.dart';
import '../domain/models/workout_models.dart';
import '../features/today/today_health_provider.dart';
import '../workouts/workout_controllers.dart';

const _storeKey = 'vytal.daily.summaries.v1';
const _maxDays = 400;

class DailySummaryState {
  const DailySummaryState({this.days = const {}});

  final Map<String, DailyHealthSummary> days;

  List<DailyHealthSummary> get sorted =>
      (days.values.toList()..sort((a, b) => a.dayKey.compareTo(b.dayKey)));

  DailyHealthSummary? forDay(DateTime local) =>
      days[DailyHealthSummary.keyFor(local)];
}

final dailySummaryStoreProvider =
    StateNotifierProvider<DailySummaryStore, DailySummaryState>((ref) {
  return DailySummaryStore()..restore();
});

/// Keeps the store in sync with already-loaded Today + workout history.
/// Does not perform extra wearable reads.
final dailySummaryCaptureProvider = Provider<void>((ref) {
  final store = ref.read(dailySummaryStoreProvider.notifier);
  ref.listen<AsyncValue<TodayHealthSnapshot>>(todayHealthProvider, (_, next) {
    next.whenData(store.captureSnapshot);
  });
  ref.listen<WorkoutHistoryState>(workoutHistoryProvider, (_, next) {
    store.applyWorkoutLoad(next.entries);
  });
  final current = ref.read(todayHealthProvider);
  current.whenData(store.captureSnapshot);
  store.applyWorkoutLoad(ref.read(workoutHistoryProvider).entries);
});

class DailySummaryStore extends StateNotifier<DailySummaryState> {
  DailySummaryStore() : super(const DailySummaryState());

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final map = <String, DailyHealthSummary>{};
      for (final json in list) {
        final summary = DailyHealthSummary.fromJson(json);
        if (summary.dayKey.isEmpty || !summary.hasAnyValue) continue;
        map[summary.dayKey] = summary;
      }
      state = DailySummaryState(days: map);
    } catch (_) {
      state = const DailySummaryState();
    }
  }

  Future<void> captureSnapshot(TodayHealthSnapshot snap) async {
    final key = DailyHealthSummary.keyFor(DateTime.now().toLocal());
    final incoming = DailyHealthSummary(
      dayKey: key,
      provenance: snap.provenance,
      updatedAt: DateTime.now().toUtc(),
      readinessScore: snap.readinessScore,
      heartRate: snap.heartRate.hasValue ? snap.heartRate.value : null,
      hrv: snap.hrv.hasValue ? snap.hrv.value : null,
      sleepMinutes:
          snap.sleep.hasValue ? snap.sleep.value!.inMinutes : null,
      steps: snap.steps,
      calories: snap.calories,
      workoutLoadMinutes: state.days[key]?.workoutLoadMinutes,
    );
    await _upsert(incoming);
  }

  Future<void> applyWorkoutLoad(List<WorkoutHistoryEntry> entries) async {
    final loads = <String, int>{};
    for (final entry in entries) {
      final key = DailyHealthSummary.keyFor(entry.completedAt.toLocal());
      loads[key] = (loads[key] ?? 0) + (entry.durationSeconds / 60).round();
    }
    if (loads.isEmpty) return;
    var next = Map<String, DailyHealthSummary>.from(state.days);
    var changed = false;
    for (final entry in loads.entries) {
      final existing = next[entry.key];
      if (existing == null) {
        next[entry.key] = DailyHealthSummary(
          dayKey: entry.key,
          provenance: DataProvenance.manual,
          updatedAt: DateTime.now().toUtc(),
          workoutLoadMinutes: entry.value,
        );
        changed = true;
        continue;
      }
      if (existing.workoutLoadMinutes == entry.value) continue;
      next[entry.key] = DailyHealthSummary(
        dayKey: existing.dayKey,
        provenance: existing.provenance,
        updatedAt: DateTime.now().toUtc(),
        readinessScore: existing.readinessScore,
        heartRate: existing.heartRate,
        hrv: existing.hrv,
        sleepMinutes: existing.sleepMinutes,
        steps: existing.steps,
        calories: existing.calories,
        workoutLoadMinutes: entry.value,
      );
      changed = true;
    }
    if (!changed) return;
    state = DailySummaryState(days: _trimmed(next));
    await _persist();
  }

  Future<void> upsertForTest(DailyHealthSummary summary) async {
    await _upsert(summary);
  }

  Future<void> _upsert(DailyHealthSummary incoming) async {
    if (!incoming.hasAnyValue) return;
    final existing = state.days[incoming.dayKey];
    final merged = existing == null ? incoming : existing.merge(incoming);
    if (existing != null &&
        existing.heartRate == merged.heartRate &&
        existing.hrv == merged.hrv &&
        existing.sleepMinutes == merged.sleepMinutes &&
        existing.steps == merged.steps &&
        existing.calories == merged.calories &&
        existing.readinessScore == merged.readinessScore &&
        existing.workoutLoadMinutes == merged.workoutLoadMinutes &&
        existing.provenance == merged.provenance) {
      return;
    }
    final next = Map<String, DailyHealthSummary>.from(state.days)
      ..[merged.dayKey] = merged;
    state = DailySummaryState(days: _trimmed(next));
    await _persist();
  }

  Map<String, DailyHealthSummary> _trimmed(
    Map<String, DailyHealthSummary> days,
  ) {
    if (days.length <= _maxDays) return days;
    final keys = days.keys.toList()..sort();
    final drop = keys.take(days.length - _maxDays).toList();
    final copy = Map<String, DailyHealthSummary>.from(days);
    for (final key in drop) {
      copy.remove(key);
    }
    return copy;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(state.sorted.map((s) => s.toJson()).toList());
    await prefs.setString(_storeKey, encoded);
  }
}
