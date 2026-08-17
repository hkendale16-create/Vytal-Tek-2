import 'data_provenance.dart';

/// One local calendar day's compact health totals.
///
/// Values are copied from already-loaded summaries or workout history.
/// Null means missing — never invent a reading to fill a chart.
class DailyHealthSummary {
  const DailyHealthSummary({
    required this.dayKey,
    required this.provenance,
    required this.updatedAt,
    this.readinessScore,
    this.heartRate,
    this.hrv,
    this.sleepMinutes,
    this.steps,
    this.calories,
    this.workoutLoadMinutes,
  });

  /// Local calendar day `yyyy-MM-dd`.
  final String dayKey;
  final DataProvenance provenance;
  final DateTime updatedAt;
  final int? readinessScore;
  final int? heartRate;
  final int? hrv;
  final int? sleepMinutes;
  final int? steps;
  final int? calories;
  final int? workoutLoadMinutes;

  bool get hasAnyValue =>
      readinessScore != null ||
      heartRate != null ||
      hrv != null ||
      sleepMinutes != null ||
      steps != null ||
      calories != null ||
      workoutLoadMinutes != null;

  int? metricValue(String metric) => switch (metric) {
        'Heart Rate' => heartRate,
        'HRV' => hrv,
        'Sleep' => sleepMinutes,
        'Activity' => steps,
        'Recovery' => readinessScore,
        'Workout Load' => workoutLoadMinutes,
        _ => heartRate,
      };

  DailyHealthSummary merge(DailyHealthSummary other) {
    return DailyHealthSummary(
      dayKey: dayKey,
      provenance: other.provenance.isProductionSafe
          ? other.provenance
          : provenance,
      updatedAt: other.updatedAt.isAfter(updatedAt) ? other.updatedAt : updatedAt,
      readinessScore: other.readinessScore ?? readinessScore,
      heartRate: other.heartRate ?? heartRate,
      hrv: other.hrv ?? hrv,
      sleepMinutes: other.sleepMinutes ?? sleepMinutes,
      steps: other.steps ?? steps,
      calories: other.calories ?? calories,
      workoutLoadMinutes: other.workoutLoadMinutes ?? workoutLoadMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'dayKey': dayKey,
        'provenance': provenance.name,
        'updatedAt': updatedAt.toIso8601String(),
        'readinessScore': readinessScore,
        'heartRate': heartRate,
        'hrv': hrv,
        'sleepMinutes': sleepMinutes,
        'steps': steps,
        'calories': calories,
        'workoutLoadMinutes': workoutLoadMinutes,
      };

  factory DailyHealthSummary.fromJson(Map<String, dynamic> json) {
    final provenanceName = json['provenance'] as String? ?? 'wearable';
    return DailyHealthSummary(
      dayKey: json['dayKey'] as String? ?? '',
      provenance: DataProvenance.values.firstWhere(
        (e) => e.name == provenanceName,
        orElse: () => DataProvenance.wearable,
      ),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      readinessScore: json['readinessScore'] as int?,
      heartRate: json['heartRate'] as int?,
      hrv: json['hrv'] as int?,
      sleepMinutes: json['sleepMinutes'] as int?,
      steps: json['steps'] as int?,
      calories: json['calories'] as int?,
      workoutLoadMinutes: json['workoutLoadMinutes'] as int?,
    );
  }

  static String keyFor(DateTime local) =>
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
