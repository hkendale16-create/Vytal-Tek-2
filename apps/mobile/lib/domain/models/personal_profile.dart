/// Progressive personal health & fitness profile (pre- and post-device).
class PersonalProfile {
  const PersonalProfile({
    this.displayName,
    this.ageRange,
    this.heightCm,
    this.weightKg,
    this.goals = const [],
    this.fitnessExperience,
    this.preferredWorkouts = const [],
    this.availableEquipment = const [],
    this.typicalWakeTime,
    this.typicalBedtime,
    this.preferredWorkoutDurationMinutes,
    this.limitations = const [],
    this.skippedSensitiveQuestions = const [],
  });

  final String? displayName;
  final String? ageRange;
  final double? heightCm;
  final double? weightKg;
  final List<String> goals;
  final String? fitnessExperience;
  final List<String> preferredWorkouts;
  final List<String> availableEquipment;
  final String? typicalWakeTime;
  final String? typicalBedtime;
  final int? preferredWorkoutDurationMinutes;
  final List<String> limitations;

  /// Sensitive onboarding answers the user chose to skip.
  final List<String> skippedSensitiveQuestions;

  PersonalProfile copyWith({
    String? displayName,
    String? ageRange,
    double? heightCm,
    double? weightKg,
    List<String>? goals,
    String? fitnessExperience,
    List<String>? preferredWorkouts,
    List<String>? availableEquipment,
    String? typicalWakeTime,
    String? typicalBedtime,
    int? preferredWorkoutDurationMinutes,
    List<String>? limitations,
    List<String>? skippedSensitiveQuestions,
  }) {
    return PersonalProfile(
      displayName: displayName ?? this.displayName,
      ageRange: ageRange ?? this.ageRange,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goals: goals ?? this.goals,
      fitnessExperience: fitnessExperience ?? this.fitnessExperience,
      preferredWorkouts: preferredWorkouts ?? this.preferredWorkouts,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      typicalWakeTime: typicalWakeTime ?? this.typicalWakeTime,
      typicalBedtime: typicalBedtime ?? this.typicalBedtime,
      preferredWorkoutDurationMinutes: preferredWorkoutDurationMinutes ??
          this.preferredWorkoutDurationMinutes,
      limitations: limitations ?? this.limitations,
      skippedSensitiveQuestions:
          skippedSensitiveQuestions ?? this.skippedSensitiveQuestions,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'ageRange': ageRange,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'goals': goals,
        'fitnessExperience': fitnessExperience,
        'preferredWorkouts': preferredWorkouts,
        'availableEquipment': availableEquipment,
        'typicalWakeTime': typicalWakeTime,
        'typicalBedtime': typicalBedtime,
        'preferredWorkoutDurationMinutes': preferredWorkoutDurationMinutes,
        'limitations': limitations,
        'skippedSensitiveQuestions': skippedSensitiveQuestions,
      };

  factory PersonalProfile.fromJson(Map<String, dynamic> json) {
    return PersonalProfile(
      displayName: json['displayName'] as String?,
      ageRange: json['ageRange'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      goals: (json['goals'] as List?)?.cast<String>() ?? const [],
      fitnessExperience: json['fitnessExperience'] as String?,
      preferredWorkouts:
          (json['preferredWorkouts'] as List?)?.cast<String>() ?? const [],
      availableEquipment:
          (json['availableEquipment'] as List?)?.cast<String>() ?? const [],
      typicalWakeTime: json['typicalWakeTime'] as String?,
      typicalBedtime: json['typicalBedtime'] as String?,
      preferredWorkoutDurationMinutes:
          json['preferredWorkoutDurationMinutes'] as int?,
      limitations: (json['limitations'] as List?)?.cast<String>() ?? const [],
      skippedSensitiveQuestions:
          (json['skippedSensitiveQuestions'] as List?)?.cast<String>() ??
              const [],
    );
  }
}

/// Physiological baseline learning state after first pairing.
enum BaselineCalibrationState {
  notStarted,
  learning,
  ready,
}

extension BaselineCalibrationStateX on BaselineCalibrationState {
  String get userFacingMessage => switch (this) {
        BaselineCalibrationState.notStarted =>
          'Baseline learning starts after you connect a Vytal wearable.',
        BaselineCalibrationState.learning =>
          'Vytal is learning your baseline. Comparisons stay low-confidence until enough history exists.',
        BaselineCalibrationState.ready =>
          'Personal baseline is available for comparisons.',
      };
}
