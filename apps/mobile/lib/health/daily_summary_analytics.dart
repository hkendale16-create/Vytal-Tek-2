import 'dart:math' as math;

import '../domain/models/daily_health_summary.dart';

/// Builds compact chart series from cached daily totals — never raw samples.
class DailySummaryAnalytics {
  const DailySummaryAnalytics();

  static const metrics = [
    'Heart Rate',
    'HRV',
    'Sleep',
    'Activity',
    'Recovery',
    'Workout Load',
  ];

  int windowDays(String range) => switch (range) {
        '7D' => 7,
        '30D' => 30,
        '90D' => 90,
        '1Y' => 365,
        _ => 7,
      };

  /// Chronological values inside [range]. Empty days are omitted, not zero-filled.
  List<double> series({
    required List<DailyHealthSummary> summaries,
    required String metric,
    required String range,
    required DateTime now,
  }) {
    final window = _inWindow(summaries, range, now);
    if (range == '1Y') {
      return _monthlyAverages(window, metric);
    }
    if (range == '90D') {
      return _weeklyAverages(window, metric);
    }
    return window
        .map((s) => s.metricValue(metric))
        .whereType<int>()
        .map((v) => v.toDouble())
        .toList();
  }

  /// Mean of last-7 sleep minutes vs last night, when both exist.
  int? sleepDebtMinutes(List<DailyHealthSummary> summaries, {DateTime? now}) {
    final today = DailyHealthSummary.keyFor((now ?? DateTime.now()).toLocal());
    final withSleep = summaries
        .where((s) => s.sleepMinutes != null)
        .toList()
      ..sort((a, b) => a.dayKey.compareTo(b.dayKey));
    if (withSleep.length < 3) return null;
    final todayHit = withSleep.where((s) => s.dayKey == today);
    final last = todayHit.isNotEmpty ? todayHit.last : withSleep.last;
    final baseline = withSleep
        .where((s) => s.dayKey != last.dayKey)
        .toList()
        .reversed
        .take(7)
        .toList();
    if (baseline.isEmpty || last.sleepMinutes == null) return null;
    final mean = baseline
            .map((s) => s.sleepMinutes!)
            .reduce((a, b) => a + b) /
        baseline.length;
    return (mean - last.sleepMinutes!).round();
  }

  /// 0–100 consistency from recent sleep durations. Null without enough days.
  int? sleepConsistency(List<DailyHealthSummary> summaries) {
    final values = summaries
        .where((s) => s.sleepMinutes != null)
        .map((s) => s.sleepMinutes!)
        .toList();
    if (values.length < 3) return null;
    final recent = values.length <= 7 ? values : values.sublist(values.length - 7);
    final mean = recent.reduce((a, b) => a + b) / recent.length;
    if (mean <= 0) return null;
    final variance = recent
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        recent.length;
    final cv = (math.sqrt(variance) / mean).clamp(0.0, 1.0);
    return ((1 - cv) * 100).round();
  }

  List<DailyHealthSummary> _inWindow(
    List<DailyHealthSummary> summaries,
    String range,
    DateTime now,
  ) {
    final days = windowDays(range);
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final startKey = DailyHealthSummary.keyFor(start);
    return summaries.where((s) => s.dayKey.compareTo(startKey) >= 0).toList()
      ..sort((a, b) => a.dayKey.compareTo(b.dayKey));
  }

  List<double> _weeklyAverages(List<DailyHealthSummary> window, String metric) {
    return _bucketAverages(window, metric, keyLength: 8);
  }

  List<double> _monthlyAverages(List<DailyHealthSummary> window, String metric) {
    return _bucketAverages(window, metric, keyLength: 7);
  }

  /// [keyLength] 7 = `yyyy-MM`, 8 = `yyyy-W` approximated by `yyyy-MM-d` week via day 1–2 of key.
  List<double> _bucketAverages(
    List<DailyHealthSummary> window,
    String metric, {
    required int keyLength,
  }) {
    final buckets = <String, List<int>>{};
    for (final summary in window) {
      final value = summary.metricValue(metric);
      if (value == null) continue;
      final bucket = keyLength == 7
          ? summary.dayKey.substring(0, 7)
          : _isoWeekKey(summary.dayKey);
      buckets.putIfAbsent(bucket, () => []).add(value);
    }
    final keys = buckets.keys.toList()..sort();
    return [
      for (final key in keys)
        buckets[key]!.reduce((a, b) => a + b) / buckets[key]!.length,
    ];
  }

  String _isoWeekKey(String dayKey) {
    final parts = dayKey.split('-');
    if (parts.length != 3) return dayKey;
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    return DailyHealthSummary.keyFor(weekStart);
  }
}
