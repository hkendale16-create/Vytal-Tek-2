import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/fitness_hub_models.dart';
import '../domain/models/workout_models.dart';
import '../fitness/equipment_workout_builder.dart';
import '../fitness/gym_discovery_controller.dart';
import '../workouts/workout_controllers.dart';

/// Starts today's calendar plan as a live session when possible.
///
/// Resolution order:
/// 1. Resume / summary if a session is already in progress
/// 2. Named `routineId` from the library
/// 3. Equipment-aware build from title / notes / duration
abstract final class TodayPlanLauncher {
  static Future<void> startFromToday({
    required BuildContext context,
    required WidgetRef ref,
    FitnessCalendarEvent? event,
    int? readinessScore,
  }) async {
    final session = ref.read(workoutSessionProvider);
    if (session.summaryPending) {
      context.push('/workouts/summary');
      return;
    }
    if (session.running || session.hasProgress || session.completed) {
      context.push('/workouts/active');
      return;
    }
    if (event == null || event.isRest || event.isCompleted) {
      context.push('/workouts');
      return;
    }

    final library = ref.read(workoutLibraryProvider);
    WorkoutRoutine? routine;
    if (event.routineId != null) {
      for (final r in library.routines) {
        if (r.id == event.routineId) {
          routine = r;
          break;
        }
      }
    }

    routine ??= _buildFromEvent(event, ref, readinessScore: readinessScore);

    if (!context.mounted) return;
    ref.read(workoutSessionProvider.notifier).startRoutine(routine);
    context.push('/workouts/active');
  }

  static String primaryLabel({
    required FitnessCalendarEvent? event,
    required bool summaryPending,
    required bool hasActiveWorkout,
    required bool isNewUser,
    int? readinessScore,
  }) {
    if (summaryPending) return 'View summary';
    if (hasActiveWorkout) return 'Resume workout';
    if (event != null && !event.isRest && !event.isCompleted) {
      if (readinessScore != null && readinessScore < 40) {
        return 'Start lighter · ${event.title}';
      }
      return 'Start ${event.title}';
    }
    if (isNewUser) return 'Start first session';
    return 'Start workout';
  }

  static WorkoutRoutine _buildFromEvent(
    FitnessCalendarEvent event,
    WidgetRef ref, {
    int? readinessScore,
  }) {
    final home = ref.read(homeGymProvider);
    final labels = EquipmentWorkoutBuilder.labelsFromItems(home.equipment);
    final minutes = event.durationMinutes ?? 40;
    final focus = [
      if (event.notes != null && event.notes!.trim().isNotEmpty) event.notes!,
      event.title,
    ].join(' ');

    var routine = EquipmentWorkoutBuilder.build(
      minutes: minutes,
      focus: focus,
      equipmentLabels: labels,
      locationName: 'Today',
    );
    routine = routine.copyWith(
      name: event.title,
      source: 'calendar',
      notes: event.notes,
    );

    // Wearable readiness can soften intensity without inventing vitals.
    if (readinessScore != null && readinessScore < 40) {
      routine = EquipmentWorkoutBuilder.makeEasier(routine);
      routine = routine.copyWith(name: '${event.title} (lighter)');
    } else if (readinessScore != null && readinessScore >= 80) {
      routine = EquipmentWorkoutBuilder.makeHarder(routine);
    }
    return routine;
  }
}
