import 'package:uuid/uuid.dart';

import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../../domain/models/operating_mode.dart';
import '../../domain/models/workout_models.dart';
import '../../features/today/today_health_provider.dart';
import '../../state/app_session_controller.dart';
import '../../workouts/exercise_library.dart';

class CoachMessage {
  const CoachMessage({
    required this.id,
    required this.fromCoach,
    required this.text,
    required this.at,
  });

  final String id;
  final bool fromCoach;
  final String text;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromCoach': fromCoach,
        'text': text,
        'at': at.toIso8601String(),
      };

  factory CoachMessage.fromJson(Map<String, dynamic> json) => CoachMessage(
        id: json['id'] as String,
        fromCoach: json['fromCoach'] as bool? ?? true,
        text: json['text'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '') ??
            DateTime.now().toUtc(),
      );
}

class CoachReply {
  const CoachReply({required this.text, this.workout});

  final String text;
  final WorkoutRoutine? workout;
}

/// Grounded, non-diagnostic Coach Vital replies.
///
/// Never invents wearable vitals. States missing data as missing.
class CoachVitalEngine {
  const CoachVitalEngine();

  static const safetyFooter =
      'Vytal is not a physician and does not diagnose conditions.';

  static const suggestedPrompts = [
    'What should I train today?',
    'Build me a 45-minute workout.',
    'What can I substitute for bench press?',
    'How has my squat progressed?',
    'What haven’t I trained this week?',
    'Build me a workout.',
    'Build a workout using only dumbbells.',
    'How am I doing today?',
    'How did I sleep?',
    'How is my recovery?',
  ];

  String welcome({
    required OperatingMode mode,
    required bool hasNotes,
  }) {
    if (mode == OperatingMode.appOnly) {
      return hasNotes
          ? 'I can use your profile and notes. Wearable vitals appear only after pairing — I will never invent sensor values.\n\n$safetyFooter'
          : 'I can use your profile now. Add notes anytime; wearable vitals appear only after pairing — I will never invent sensor values.\n\n$safetyFooter';
    }
    return 'Connected Mode is active. I only reference verified wearable summaries and your profile.\n\n$safetyFooter';
  }

  String reply({
    required String userText,
    required AppSession session,
    required TodayHealthSnapshot? health,
    required List<String> recentNoteSnippets,
    required bool advanced,
    List<String> recentWorkoutNames = const [],
    String? currentWorkoutName,
  }) {
    final text = userText.trim();
    final lower = text.toLowerCase();

    if (_looksLikeDiagnosisRequest(lower)) {
      return 'I can’t diagnose or interpret symptoms as a clinician would. '
          'If you feel unwell, contact a qualified professional or emergency services. '
          'I can help with habits, routines, and what your app data actually shows.\n\n$safetyFooter';
    }

    if (lower.contains('doing today') ||
        lower.contains('how am i') ||
        lower.contains('today?')) {
      return _todayReply(
        session: session,
        health: health,
        recentWorkoutNames: recentWorkoutNames,
      );
    }

    if (lower.contains('heart') ||
        lower.contains(' hr') ||
        lower.startsWith('hr') ||
        lower.contains('bpm')) {
      return _metricReply(
        label: 'Heart rate',
        reading: health?.heartRate,
        session: session,
        extra: lower.contains('higher')
            ? ' I can only comment on the latest verified reading — I won’t invent a cause.'
            : '',
      );
    }
    if (lower.contains('sleep')) {
      return _metricReply(
        label: 'Sleep',
        reading: health?.sleep,
        session: session,
        formatDuration: true,
      );
    }
    if (lower.contains('hrv') || lower.contains('recovery')) {
      return _metricReply(
        label: 'HRV',
        reading: health?.hrv,
        session: session,
      );
    }
    if (lower.contains('note') || lower.contains('journal')) {
      if (recentNoteSnippets.isEmpty) {
        return 'You don’t have notes yet. Add one from Notes — I’ll use them for context without treating them as sensor data.';
      }
      final preview = recentNoteSnippets.take(3).map((e) => '• $e').join('\n');
      return 'Here’s what I’m holding from your recent notes (user-entered, not wearable):\n$preview';
    }
    if (lower.contains('what should i train') ||
        lower.contains('train today')) {
      final goals = session.profile.preferredWorkouts;
      final hint = goals.isEmpty
          ? 'No preferred workouts are saved on your profile yet.'
          : 'Your profile lists: ${goals.take(3).join(', ')}.';
      return '$hint I can build a structured session if you tell me a muscle group or duration.\n\n$safetyFooter';
    }
    if (lower.contains('plan') ||
        lower.contains('workout') ||
        lower.contains('train')) {
      if (currentWorkoutName != null) {
        return 'You already have "$currentWorkoutName" in progress. I can still generate another structured session you can save.\n\n$safetyFooter';
      }
      if (advanced) {
        final recovery = health?.hrv.hasValue == true
            ? 'Your latest verified HRV reading is ${health!.hrv.value} ms.'
            : 'I don’t have a verified HRV reading yet, so intensity advice stays general.';
        return 'Let’s keep training practical. $recovery '
            'Prefer a session that matches your stated goals and available time. '
            'I won’t invent readiness scores.\n\n$safetyFooter';
      }
      return 'I can sketch a structured routine from your request. Adaptive intensity that uses recovery metrics needs Pro (ai.advanced).\n\n$safetyFooter';
    }

    final mode = session.operatingMode == OperatingMode.appOnly
        ? 'App-Only Mode'
        : 'Connected Mode';
    final name = session.profile.displayName?.trim();
    final greet = (name == null || name.isEmpty) ? '' : '$name, ';
    return '${greet}I’m here in $mode. Ask about sleep, heart rate, HRV, notes, or a workout plan — '
        'I’ll only use verified data and will say when something is missing.\n\n$safetyFooter';
  }

  CoachReply compose({
    required String userText,
    required AppSession session,
    required TodayHealthSnapshot? health,
    required List<String> recentNoteSnippets,
    required bool advanced,
    List<String> recentWorkoutNames = const [],
    String? currentWorkoutName,
  }) {
    final text = reply(
      userText: userText,
      session: session,
      health: health,
      recentNoteSnippets: recentNoteSnippets,
      advanced: advanced,
      recentWorkoutNames: recentWorkoutNames,
      currentWorkoutName: currentWorkoutName,
    );
    final workout = tryBuildWorkout(userText, session: session);
    if (workout == null) return CoachReply(text: text);
    return CoachReply(
      text: '$text\n\nStructured session: ${workout.name}. '
          'Start it, save it to My Routines, or ask me to regenerate.',
      workout: workout,
    );
  }

  WorkoutRoutine? tryBuildWorkout(
    String userText, {
    AppSession? session,
  }) {
    final lower = userText.toLowerCase();
    final wants = lower.contains('build') ||
        lower.contains('create a workout') ||
        lower.contains('generate') ||
        lower.contains('give me a') ||
        lower.contains('what should i train') ||
        (lower.contains('workout') &&
            (lower.contains('plan') ||
                lower.contains('routine') ||
                lower.contains('session') ||
                lower.contains('minute') ||
                lower.contains('using') ||
                lower.contains('dumbbell') ||
                lower.contains('chest') ||
                lower.contains('me')));
    if (!wants) return null;
    return buildStructuredWorkout(userText, session: session);
  }

  WorkoutRoutine buildStructuredWorkout(
    String userText, {
    AppSession? session,
  }) {
    final lower = userText.toLowerCase();
    final minutes = _parseMinutes(lower) ??
        session?.profile.preferredWorkoutDurationMinutes ??
        30;
    final uuid = const Uuid();
    if (lower.contains('run') ||
        (lower.contains('walk') && !lower.contains('dumbbell'))) {
      return WorkoutRoutine(
        id: uuid.v4(),
        name: 'Outdoor cardio — $minutes min',
        activityKind: WorkoutActivityKind.cardio,
        source: 'ai',
        exercises: [
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Easy walk / jog',
            muscleGroup: MuscleGroup.fullBody,
            equipment: 'None',
            sets: 1,
            durationSeconds: (minutes * 60 * 0.7).round().clamp(60, 3600),
            restSeconds: 0,
          ),
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Strides',
            muscleGroup: MuscleGroup.fullBody,
            equipment: 'None',
            sets: 4,
            durationSeconds: 30,
            restSeconds: 45,
          ),
        ],
      );
    }
    if (lower.contains('hiit') || lower.contains('interval')) {
      final rounds = (minutes / 1.5).round().clamp(6, 16);
      return WorkoutRoutine(
        id: uuid.v4(),
        name: 'HIIT intervals — $minutes min',
        activityKind: WorkoutActivityKind.hiit,
        source: 'ai',
        exercises: [
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Work',
            muscleGroup: MuscleGroup.fullBody,
            equipment: 'Bodyweight',
            sets: rounds,
            durationSeconds: 30,
            restSeconds: 30,
          ),
        ],
      );
    }

    final group = _muscleFrom(lower) ?? MuscleGroup.chest;
    final dumbbellOnly = lower.contains('dumbbell');
    var catalog = ExerciseLibrary.forGroup(group);
    if (dumbbellOnly) {
      final filtered =
          catalog.where((e) => e.equipment.toLowerCase().contains('dumbbell'));
      if (filtered.isNotEmpty) catalog = filtered.toList();
    }
    final take = (minutes / 12).round().clamp(3, 5);
    final picked = catalog.take(take).toList();
    if (picked.isEmpty) {
      picked.addAll(ExerciseLibrary.forGroup(MuscleGroup.fullBody).take(3));
    }
    return WorkoutRoutine(
      id: uuid.v4(),
      name: '${group.label} Strength — $minutes min',
      activityKind: WorkoutActivityKind.strength,
      source: 'ai',
      exercises: [
        for (final def in picked) def.toExercise(),
      ],
    );
  }

  MuscleGroup? _muscleFrom(String lower) {
    for (final group in MuscleGroup.values) {
      if (lower.contains(group.aiHint) ||
          lower.contains(group.label.toLowerCase())) {
        return group;
      }
    }
    return null;
  }

  String _todayReply({
    required AppSession session,
    required TodayHealthSnapshot? health,
    required List<String> recentWorkoutNames,
  }) {
    final parts = <String>[];
    if (health?.heartRate.hasValue == true) {
      parts.add('HR ${health!.heartRate.value} ${health.heartRate.unit ?? 'BPM'}');
    }
    if (health?.sleep.hasValue == true) {
      final d = health!.sleep.value!;
      parts.add('sleep ${d.inHours}h ${d.inMinutes.remainder(60)}m');
    }
    if (health?.hrv.hasValue == true) {
      parts.add('HRV ${health!.hrv.value} ms');
    }
    if (parts.isEmpty) {
      if (session.operatingMode == OperatingMode.appOnly) {
        return 'I don’t have wearable vitals yet because no device is paired. '
            'I can still build workouts from your profile and notes.\n\n$safetyFooter';
      }
      return 'I don’t have a recent health summary to judge today. '
          'Connect your Vytal device or sync it first — I won’t invent scores.\n\n$safetyFooter';
    }
    final workouts = recentWorkoutNames.isEmpty
        ? 'No saved workouts in history yet.'
        : 'Recent sessions: ${recentWorkoutNames.take(3).join(', ')}.';
    return 'Here’s what I actually have: ${parts.join(', ')}. $workouts '
        'This is not a medical assessment.\n\n$safetyFooter';
  }

  int? _parseMinutes(String lower) {
    final match = RegExp(r'(\d+)\s*(min|minute)').firstMatch(lower);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  bool _looksLikeDiagnosisRequest(String lower) {
    const triggers = [
      'diagnose',
      'diagnosis',
      'do i have',
      'is this cancer',
      'prescribe',
      'what disease',
      'am i sick',
    ];
    return triggers.any(lower.contains);
  }

  String _metricReply({
    required String label,
    required HealthMetricReading<dynamic>? reading,
    required AppSession session,
    bool formatDuration = false,
    String extra = '',
  }) {
    if (reading == null || !reading.hasValue) {
      if (session.operatingMode == OperatingMode.appOnly) {
        return '$label isn’t available yet — no wearable is paired. '
            'I won’t invent a $label value.\n\n$safetyFooter';
      }
      return '$label has no verified reading right now (unsupported, disconnected, or not synced). '
          'I won’t invent one.\n\n$safetyFooter';
    }
    final value = reading.value;
    final shown = formatDuration && value is Duration
        ? '${value.inHours}h ${value.inMinutes.remainder(60)}m'
        : '$value${(reading.unit ?? '').isNotEmpty ? ' ${reading.unit}' : ''}';
    final provenance = reading.provenance == DataProvenance.demo
        ? ' (labeled Demo — not production)'
        : ' (wearable / verified summary)';
    return 'Latest $label: $shown$provenance.$extra This is informational, not a medical assessment.\n\n$safetyFooter';
  }
}
