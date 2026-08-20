/// Fitness calendar, plans, gyms, equipment — local-first domain models.
///
/// UI → controllers → repositories → local/backend providers.
/// Do not couple screens directly to SharedPreferences or a cloud SDK.
library;

import 'package:uuid/uuid.dart';

import 'workout_models.dart';

// ── Equipment ──────────────────────────────────────────────────────────────

enum GymEquipmentItem {
  barbell,
  dumbbells,
  adjustableDumbbells,
  squatRack,
  bench,
  cableMachine,
  smithMachine,
  treadmills,
  bikes,
  rowingMachines,
  machines,
  pullUpStation,
  kettlebells,
  resistanceBands,
  noEquipment,
}

extension GymEquipmentItemX on GymEquipmentItem {
  String get label => switch (this) {
        GymEquipmentItem.barbell => 'Barbell',
        GymEquipmentItem.dumbbells => 'Dumbbells',
        GymEquipmentItem.adjustableDumbbells => 'Adjustable dumbbells',
        GymEquipmentItem.squatRack => 'Squat rack',
        GymEquipmentItem.bench => 'Bench',
        GymEquipmentItem.cableMachine => 'Cable machine',
        GymEquipmentItem.smithMachine => 'Smith machine',
        GymEquipmentItem.treadmills => 'Treadmills',
        GymEquipmentItem.bikes => 'Bikes',
        GymEquipmentItem.rowingMachines => 'Rowing machines',
        GymEquipmentItem.machines => 'Machines',
        GymEquipmentItem.pullUpStation => 'Pull-up station',
        GymEquipmentItem.kettlebells => 'Kettlebells',
        GymEquipmentItem.resistanceBands => 'Resistance bands',
        GymEquipmentItem.noEquipment => 'No equipment',
      };

  static GymEquipmentItem? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final item in GymEquipmentItem.values) {
      if (item.name == raw) return item;
    }
    return null;
  }
}

/// Home gym owned equipment — filters workouts without claiming commercial gym stock.
class HomeGymProfile {
  const HomeGymProfile({this.equipment = const []});

  final List<GymEquipmentItem> equipment;

  bool get isEmpty => equipment.isEmpty;

  HomeGymProfile copyWith({List<GymEquipmentItem>? equipment}) =>
      HomeGymProfile(equipment: equipment ?? this.equipment);

  Map<String, dynamic> toJson() => {
        'equipment': equipment.map((e) => e.name).toList(),
      };

  factory HomeGymProfile.fromJson(Map<String, dynamic> json) {
    final raw = (json['equipment'] as List?) ?? const [];
    return HomeGymProfile(
      equipment: raw
          .map((e) => GymEquipmentItemX.tryParse(e.toString()))
          .whereType<GymEquipmentItem>()
          .toList(),
    );
  }
}

// ── Calendar ───────────────────────────────────────────────────────────────

enum FitnessEventKind {
  scheduledWorkout,
  completedWorkout,
  restDay,
  cardio,
  strength,
  calisthenics,
  fitnessClass,
  personalGoal,
  weighIn,
  progressCheck,
  custom,
}

extension FitnessEventKindX on FitnessEventKind {
  String get label => switch (this) {
        FitnessEventKind.scheduledWorkout => 'Workout',
        FitnessEventKind.completedWorkout => 'Completed',
        FitnessEventKind.restDay => 'Rest',
        FitnessEventKind.cardio => 'Cardio',
        FitnessEventKind.strength => 'Strength',
        FitnessEventKind.calisthenics => 'Calisthenics',
        FitnessEventKind.fitnessClass => 'Class',
        FitnessEventKind.personalGoal => 'Goal',
        FitnessEventKind.weighIn => 'Weigh-in',
        FitnessEventKind.progressCheck => 'Progress check',
        FitnessEventKind.custom => 'Custom',
      };

  static FitnessEventKind fromJson(String? raw) {
    return FitnessEventKind.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => FitnessEventKind.custom,
    );
  }
}

enum FitnessEventStatus { planned, completed, skipped, cancelled }

extension FitnessEventStatusX on FitnessEventStatus {
  static FitnessEventStatus fromJson(String? raw) {
    return FitnessEventStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => FitnessEventStatus.planned,
    );
  }
}

class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.minutesBefore = 30,
  });

  final bool enabled;
  final int minutesBefore;

  ReminderSettings copyWith({bool? enabled, int? minutesBefore}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        minutesBefore: minutesBefore ?? this.minutesBefore,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'minutesBefore': minutesBefore,
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) =>
      ReminderSettings(
        enabled: json['enabled'] as bool? ?? false,
        minutesBefore: json['minutesBefore'] as int? ?? 30,
      );
}

class FitnessCalendarEvent {
  const FitnessCalendarEvent({
    required this.id,
    required this.title,
    required this.kind,
    required this.date,
    this.status = FitnessEventStatus.planned,
    this.timeOfDayMinutes,
    this.durationMinutes,
    this.reminder = const ReminderSettings(),
    this.routineId,
    this.planId,
    this.historyEntryId,
    this.gymId,
    this.notes,
    this.setsCompleted,
    this.volumeKg,
  });

  final String id;
  final String title;
  final FitnessEventKind kind;
  final DateTime date;
  final FitnessEventStatus status;
  /// Minutes from midnight local, optional.
  final int? timeOfDayMinutes;
  final int? durationMinutes;
  final ReminderSettings reminder;
  final String? routineId;
  final String? planId;
  final String? historyEntryId;
  final String? gymId;
  final String? notes;
  final int? setsCompleted;
  final double? volumeKg;

  bool get isCompleted =>
      status == FitnessEventStatus.completed ||
      kind == FitnessEventKind.completedWorkout;

  bool get isRest => kind == FitnessEventKind.restDay;

  DateTime get dayKey => DateTime(date.year, date.month, date.day);

  FitnessCalendarEvent copyWith({
    String? title,
    FitnessEventKind? kind,
    DateTime? date,
    FitnessEventStatus? status,
    int? timeOfDayMinutes,
    int? durationMinutes,
    ReminderSettings? reminder,
    String? routineId,
    String? planId,
    String? historyEntryId,
    String? gymId,
    String? notes,
    int? setsCompleted,
    double? volumeKg,
    bool clearTime = false,
    bool clearDuration = false,
  }) {
    return FitnessCalendarEvent(
      id: id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      date: date ?? this.date,
      status: status ?? this.status,
      timeOfDayMinutes:
          clearTime ? null : (timeOfDayMinutes ?? this.timeOfDayMinutes),
      durationMinutes:
          clearDuration ? null : (durationMinutes ?? this.durationMinutes),
      reminder: reminder ?? this.reminder,
      routineId: routineId ?? this.routineId,
      planId: planId ?? this.planId,
      historyEntryId: historyEntryId ?? this.historyEntryId,
      gymId: gymId ?? this.gymId,
      notes: notes ?? this.notes,
      setsCompleted: setsCompleted ?? this.setsCompleted,
      volumeKg: volumeKg ?? this.volumeKg,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'date': date.toIso8601String(),
        'status': status.name,
        'timeOfDayMinutes': timeOfDayMinutes,
        'durationMinutes': durationMinutes,
        'reminder': reminder.toJson(),
        'routineId': routineId,
        'planId': planId,
        'historyEntryId': historyEntryId,
        'gymId': gymId,
        'notes': notes,
        'setsCompleted': setsCompleted,
        'volumeKg': volumeKg,
      };

  factory FitnessCalendarEvent.fromJson(Map<String, dynamic> json) =>
      FitnessCalendarEvent(
        id: json['id'] as String? ?? const Uuid().v4(),
        title: json['title'] as String? ?? 'Event',
        kind: FitnessEventKindX.fromJson(json['kind'] as String?),
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
        status: FitnessEventStatusX.fromJson(json['status'] as String?),
        timeOfDayMinutes: json['timeOfDayMinutes'] as int?,
        durationMinutes: json['durationMinutes'] as int?,
        reminder: json['reminder'] is Map<String, dynamic>
            ? ReminderSettings.fromJson(json['reminder'] as Map<String, dynamic>)
            : const ReminderSettings(),
        routineId: json['routineId'] as String?,
        planId: json['planId'] as String?,
        historyEntryId: json['historyEntryId'] as String?,
        gymId: json['gymId'] as String?,
        notes: json['notes'] as String?,
        setsCompleted: json['setsCompleted'] as int?,
        volumeKg: (json['volumeKg'] as num?)?.toDouble(),
      );

  /// Auto-history entry from a completed workout — no double logging.
  factory FitnessCalendarEvent.fromHistory(WorkoutHistoryEntry entry) {
    final local = entry.completedAt.toLocal();
    return FitnessCalendarEvent(
      id: 'hist-${entry.id}',
      title: entry.name,
      kind: FitnessEventKind.completedWorkout,
      date: DateTime(local.year, local.month, local.day),
      status: FitnessEventStatus.completed,
      timeOfDayMinutes: local.hour * 60 + local.minute,
      durationMinutes: (entry.durationSeconds / 60).round(),
      historyEntryId: entry.id,
      setsCompleted: entry.setLogs.where((s) => s.completed).length,
      volumeKg: entry.trainingVolumeKg,
      notes: entry.notes,
    );
  }
}

// ── Workout plans ──────────────────────────────────────────────────────────

enum PlanGoal {
  buildMuscle,
  strength,
  fatLossConditioning,
  generalFitness,
  calisthenics,
  running,
  homeWorkouts,
}

extension PlanGoalX on PlanGoal {
  String get label => switch (this) {
        PlanGoal.buildMuscle => 'Build Muscle',
        PlanGoal.strength => 'Strength',
        PlanGoal.fatLossConditioning => 'Fat Loss / Conditioning',
        PlanGoal.generalFitness => 'General Fitness',
        PlanGoal.calisthenics => 'Calisthenics',
        PlanGoal.running => 'Running',
        PlanGoal.homeWorkouts => 'Home Workouts',
      };

  static PlanGoal fromJson(String? raw) => PlanGoal.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => PlanGoal.generalFitness,
      );
}

enum PlanDifficulty { beginner, intermediate, advanced }

extension PlanDifficultyX on PlanDifficulty {
  String get label => switch (this) {
        PlanDifficulty.beginner => 'Beginner',
        PlanDifficulty.intermediate => 'Intermediate',
        PlanDifficulty.advanced => 'Advanced',
      };

  static PlanDifficulty fromJson(String? raw) =>
      PlanDifficulty.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => PlanDifficulty.beginner,
      );
}

class PlanDayTemplate {
  const PlanDayTemplate({
    required this.weekday,
    required this.title,
    this.isRest = false,
    this.optional = false,
    this.routineId,
    this.focus,
  });

  /// 1 = Monday … 7 = Sunday
  final int weekday;
  final String title;
  final bool isRest;
  final bool optional;
  final String? routineId;
  final String? focus;

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'title': title,
        'isRest': isRest,
        'optional': optional,
        'routineId': routineId,
        'focus': focus,
      };

  factory PlanDayTemplate.fromJson(Map<String, dynamic> json) =>
      PlanDayTemplate(
        weekday: json['weekday'] as int? ?? 1,
        title: json['title'] as String? ?? 'Session',
        isRest: json['isRest'] as bool? ?? false,
        optional: json['optional'] as bool? ?? false,
        routineId: json['routineId'] as String?,
        focus: json['focus'] as String?,
      );
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.goal,
    required this.difficulty,
    required this.weeks,
    required this.daysPerWeek,
    required this.durationMin,
    required this.durationMax,
    required this.equipment,
    required this.muscleGroups,
    required this.weeklyStructure,
    this.tagline,
    this.advanced = false,
  });

  final String id;
  final String name;
  final PlanGoal goal;
  final PlanDifficulty difficulty;
  final int weeks;
  final String daysPerWeek;
  final int durationMin;
  final int durationMax;
  final List<String> equipment;
  final List<String> muscleGroups;
  final List<PlanDayTemplate> weeklyStructure;
  final String? tagline;
  final bool advanced;

  String get durationLabel => '$durationMin–$durationMax min';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'goal': goal.name,
        'difficulty': difficulty.name,
        'weeks': weeks,
        'daysPerWeek': daysPerWeek,
        'durationMin': durationMin,
        'durationMax': durationMax,
        'equipment': equipment,
        'muscleGroups': muscleGroups,
        'weeklyStructure': weeklyStructure.map((e) => e.toJson()).toList(),
        'tagline': tagline,
        'advanced': advanced,
      };

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String? ?? 'Plan',
        goal: PlanGoalX.fromJson(json['goal'] as String?),
        difficulty: PlanDifficultyX.fromJson(json['difficulty'] as String?),
        weeks: json['weeks'] as int? ?? 4,
        daysPerWeek: json['daysPerWeek'] as String? ?? '3–4',
        durationMin: json['durationMin'] as int? ?? 30,
        durationMax: json['durationMax'] as int? ?? 45,
        equipment: (json['equipment'] as List?)?.cast<String>() ?? const [],
        muscleGroups:
            (json['muscleGroups'] as List?)?.cast<String>() ?? const [],
        weeklyStructure: ((json['weeklyStructure'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(PlanDayTemplate.fromJson)
            .toList(),
        tagline: json['tagline'] as String?,
        advanced: json['advanced'] as bool? ?? false,
      );
}

class PlanEnrollment {
  const PlanEnrollment({
    required this.id,
    required this.planId,
    required this.startDate,
    required this.trainingWeekdays,
    this.preferredTimeMinutes,
    this.reminder = const ReminderSettings(),
    this.active = true,
  });

  final String id;
  final String planId;
  final DateTime startDate;
  final List<int> trainingWeekdays;
  final int? preferredTimeMinutes;
  final ReminderSettings reminder;
  final bool active;

  Map<String, dynamic> toJson() => {
        'id': id,
        'planId': planId,
        'startDate': startDate.toIso8601String(),
        'trainingWeekdays': trainingWeekdays,
        'preferredTimeMinutes': preferredTimeMinutes,
        'reminder': reminder.toJson(),
        'active': active,
      };

  factory PlanEnrollment.fromJson(Map<String, dynamic> json) => PlanEnrollment(
        id: json['id'] as String? ?? const Uuid().v4(),
        planId: json['planId'] as String? ?? '',
        startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ??
            DateTime.now(),
        trainingWeekdays:
            (json['trainingWeekdays'] as List?)?.cast<int>() ?? const [],
        preferredTimeMinutes: json['preferredTimeMinutes'] as int?,
        reminder: json['reminder'] is Map<String, dynamic>
            ? ReminderSettings.fromJson(json['reminder'] as Map<String, dynamic>)
            : const ReminderSettings(),
        active: json['active'] as bool? ?? true,
      );
}

// ── Gyms ───────────────────────────────────────────────────────────────────

enum GymType {
  commercial,
  independent,
  fitnessCenter,
  crossfit,
  boxingMma,
  climbing,
  recreation,
  specialized,
  home,
  unknown,
}

extension GymTypeX on GymType {
  String get label => switch (this) {
        GymType.commercial => 'Commercial gym',
        GymType.independent => 'Independent gym',
        GymType.fitnessCenter => 'Fitness center',
        GymType.crossfit => 'CrossFit-style',
        GymType.boxingMma => 'Boxing / MMA',
        GymType.climbing => 'Climbing',
        GymType.recreation => 'Recreation center',
        GymType.specialized => 'Specialized training',
        GymType.home => 'Home gym',
        GymType.unknown => 'Fitness facility',
      };

  static GymType fromJson(String? raw) => GymType.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => GymType.unknown,
      );
}

class GymPlace {
  const GymPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.type = GymType.unknown,
    this.address,
    this.distanceMeters,
    this.hoursLabel,
    this.phone,
    this.website,
    this.amenities = const [],
    this.photoUrls = const [],
    this.equipmentKnown = false,
    this.equipment = const [],
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final GymType type;
  final String? address;
  final double? distanceMeters;
  final String? hoursLabel;
  final String? phone;
  final String? website;
  final List<String> amenities;
  final List<String> photoUrls;
  /// Only true when user-confirmed or a trusted source provided equipment.
  final bool equipmentKnown;
  final List<GymEquipmentItem> equipment;

  String get distanceLabel {
    final m = distanceMeters;
    if (m == null) return '';
    if (m < 1609) return '${(m / 1609 * 10).round() / 10} mi';
    return '${(m / 1609).toStringAsFixed(1)} mi';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'type': type.name,
        'address': address,
        'distanceMeters': distanceMeters,
        'hoursLabel': hoursLabel,
        'phone': phone,
        'website': website,
        'amenities': amenities,
        'photoUrls': photoUrls,
        'equipmentKnown': equipmentKnown,
        'equipment': equipment.map((e) => e.name).toList(),
      };

  factory GymPlace.fromJson(Map<String, dynamic> json) => GymPlace(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String? ?? 'Gym',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        type: GymTypeX.fromJson(json['type'] as String?),
        address: json['address'] as String?,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
        hoursLabel: json['hoursLabel'] as String?,
        phone: json['phone'] as String?,
        website: json['website'] as String?,
        amenities: (json['amenities'] as List?)?.cast<String>() ?? const [],
        photoUrls: (json['photoUrls'] as List?)?.cast<String>() ?? const [],
        equipmentKnown: json['equipmentKnown'] as bool? ?? false,
        equipment: ((json['equipment'] as List?) ?? const [])
            .map((e) => GymEquipmentItemX.tryParse(e.toString()))
            .whereType<GymEquipmentItem>()
            .toList(),
      );
}

class SavedGym {
  const SavedGym({
    required this.place,
    required this.savedAt,
    this.userEquipment = const [],
    this.favorite = true,
  });

  final GymPlace place;
  final DateTime savedAt;
  final List<GymEquipmentItem> userEquipment;
  final bool favorite;

  /// Prefer user-confirmed equipment; never invent facility stock.
  List<GymEquipmentItem> get effectiveEquipment =>
      userEquipment.isNotEmpty ? userEquipment : place.equipment;

  bool get hasReliableEquipment =>
      userEquipment.isNotEmpty || place.equipmentKnown;

  Map<String, dynamic> toJson() => {
        'place': place.toJson(),
        'savedAt': savedAt.toIso8601String(),
        'userEquipment': userEquipment.map((e) => e.name).toList(),
        'favorite': favorite,
      };

  factory SavedGym.fromJson(Map<String, dynamic> json) => SavedGym(
        place: GymPlace.fromJson(json['place'] as Map<String, dynamic>? ?? {}),
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        userEquipment: ((json['userEquipment'] as List?) ?? const [])
            .map((e) => GymEquipmentItemX.tryParse(e.toString()))
            .whereType<GymEquipmentItem>()
            .toList(),
        favorite: json['favorite'] as bool? ?? true,
      );
}

// ── Progress photos (private by default) ───────────────────────────────────

class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.capturedAt,
    required this.localPath,
    this.angle = 'front',
    this.weightKg,
    this.notes,
  });

  final String id;
  final DateTime capturedAt;
  final String localPath;
  final String angle; // front | side | back
  final double? weightKg;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'capturedAt': capturedAt.toIso8601String(),
        'localPath': localPath,
        'angle': angle,
        'weightKg': weightKg,
        'notes': notes,
      };

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) => ProgressPhoto(
        id: json['id'] as String? ?? const Uuid().v4(),
        capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        localPath: json['localPath'] as String? ?? '',
        angle: json['angle'] as String? ?? 'front',
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
      );
}

// ── Strength PRs ───────────────────────────────────────────────────────────

class StrengthPersonalRecord {
  const StrengthPersonalRecord({
    required this.exerciseName,
    required this.weightKg,
    required this.achievedAt,
    this.previousWeightKg,
    this.reps,
  });

  final String exerciseName;
  final double weightKg;
  final DateTime achievedAt;
  final double? previousWeightKg;
  final int? reps;

  double? get deltaKg =>
      previousWeightKg == null ? null : weightKg - previousWeightKg!;

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'weightKg': weightKg,
        'achievedAt': achievedAt.toIso8601String(),
        'previousWeightKg': previousWeightKg,
        'reps': reps,
      };

  factory StrengthPersonalRecord.fromJson(Map<String, dynamic> json) =>
      StrengthPersonalRecord(
        exerciseName: json['exerciseName'] as String? ?? 'Lift',
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
        achievedAt: DateTime.tryParse(json['achievedAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        previousWeightKg: (json['previousWeightKg'] as num?)?.toDouble(),
        reps: json['reps'] as int?,
      );
}
