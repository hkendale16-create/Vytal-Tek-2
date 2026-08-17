import 'package:uuid/uuid.dart';

import '../../domain/models/data_provenance.dart';
import '../../domain/models/health_metric.dart';
import '../../domain/models/operating_mode.dart';
import '../../domain/models/workout_models.dart';
import '../../features/today/today_health_provider.dart';
import '../../state/app_session_controller.dart';

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
    'How am I doing today?',
    'Should I work out today?',
    'Why is my HRV lower?',
    'How did I sleep?',
    'Build me a workout.',
    'How has my recovery changed?',
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
  }) {
    final text = userText.trim();
    final lower = text.toLowerCase();

    if (_looksLikeDiagnosisRequest(lower)) {
      return 'I can’t diagnose or interpret symptoms as a clinician would. '
          'If you feel unwell, contact a qualified professional or emergency services. '
          'I can help with habits, routines, and what your app data actually shows.\n\n$safetyFooter';
    }

    if (lower.contains('heart') ||
        lower.contains(' hr') ||
        lower.startsWith('hr') ||
        lower.contains('bpm')) {
      return _metricReply(
        label: 'Heart rate',
        reading: health?.heartRate,
        session: session,
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
    if (lower.contains('plan') ||
        lower.contains('workout') ||
        lower.contains('train')) {
      if (advanced) {
        final recovery = health?.hrv.hasValue == true
            ? 'Your latest verified HRV reading is ${health!.hrv.value} ms.'
            : 'I don’t have a verified HRV reading yet, so intensity advice stays general.';
        return 'Let’s keep training practical. $recovery '
            'Prefer a session that matches your stated goals and available time. '
            'I won’t invent readiness scores.\n\n$safetyFooter';
      }
      return 'I can help sketch a simple routine from your goals. Adaptive intensity that uses recovery metrics needs Pro (ai.advanced).\n\n$safetyFooter';
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
  }) {
    final text = reply(
      userText: userText,
      session: session,
      health: health,
      recentNoteSnippets: recentNoteSnippets,
      advanced: advanced,
    );
    final workout = tryBuildWorkout(userText);
    if (workout == null) return CoachReply(text: text);
    return CoachReply(
      text: '$text\n\nStructured session: ${workout.name}. '
          'Start it, save it to My Routines, or ask me to regenerate.',
      workout: workout,
    );
  }

  WorkoutRoutine? tryBuildWorkout(String userText) {
    final lower = userText.toLowerCase();
    final wants = lower.contains('build') ||
        lower.contains('create a workout') ||
        lower.contains('generate') ||
        (lower.contains('workout') &&
            (lower.contains('plan') ||
                lower.contains('routine') ||
                lower.contains('session') ||
                lower.contains('30') ||
                lower.contains('minute')));
    if (!wants &&
        !(lower.contains('workout') &&
            (lower.contains('me') || lower.contains('make')))) {
      return null;
    }
    return buildStructuredWorkout(userText);
  }

  WorkoutRoutine buildStructuredWorkout(String userText) {
    final lower = userText.toLowerCase();
    final minutes = _parseMinutes(lower) ?? 30;
    final uuid = const Uuid();
    if (lower.contains('run') || lower.contains('walk')) {
      return WorkoutRoutine(
        id: uuid.v4(),
        name: 'Outdoor cardio — $minutes min',
        activityKind: WorkoutActivityKind.cardio,
        source: 'ai',
        exercises: [
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Easy walk / jog',
            sets: 1,
            durationSeconds: (minutes * 60 * 0.7).round().clamp(60, 3600),
            restSeconds: 0,
          ),
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Strides',
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
            sets: rounds,
            durationSeconds: 30,
            restSeconds: 30,
          ),
        ],
      );
    }
    return WorkoutRoutine(
      id: uuid.v4(),
      name: 'Chest Strength — $minutes min',
      activityKind: WorkoutActivityKind.strength,
      source: 'ai',
      exercises: [
        WorkoutExercise(
          id: uuid.v4(),
          name: 'Dumbbell Press',
          sets: 3,
          reps: 10,
          restSeconds: 60,
        ),
        WorkoutExercise(
          id: uuid.v4(),
          name: 'Incline Press',
          sets: 3,
          reps: 10,
          restSeconds: 60,
        ),
        WorkoutExercise(
          id: uuid.v4(),
          name: 'Push-ups',
          sets: 3,
          reps: 12,
          restSeconds: 45,
        ),
      ],
    );
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
    return 'Latest $label: $shown$provenance. This is informational, not a medical assessment.\n\n$safetyFooter';
  }
}
