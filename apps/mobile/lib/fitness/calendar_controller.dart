import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/fitness_hub_models.dart';
import '../domain/models/workout_models.dart';
import '../workouts/workout_controllers.dart';
import 'plan_library.dart';
import 'repositories/fitness_repositories.dart';
import 'repositories/local_fitness_store.dart';

class FitnessCalendarState {
  const FitnessCalendarState({
    this.events = const [],
    this.enrollments = const [],
    this.ready = false,
  });

  final List<FitnessCalendarEvent> events;
  final List<PlanEnrollment> enrollments;
  final bool ready;

  FitnessCalendarState copyWith({
    List<FitnessCalendarEvent>? events,
    List<PlanEnrollment>? enrollments,
    bool? ready,
  }) {
    return FitnessCalendarState(
      events: events ?? this.events,
      enrollments: enrollments ?? this.enrollments,
      ready: ready ?? this.ready,
    );
  }

  List<FitnessCalendarEvent> forDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return events
        .where((e) => e.dayKey == key)
        .toList()
      ..sort((a, b) => (a.timeOfDayMinutes ?? 0).compareTo(b.timeOfDayMinutes ?? 0));
  }

  List<FitnessCalendarEvent> forWeek(DateTime weekStart) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return events
        .where((e) => !e.dayKey.isBefore(start) && e.dayKey.isBefore(end))
        .toList();
  }
}

final fitnessCalendarProvider =
    StateNotifierProvider<FitnessCalendarController, FitnessCalendarState>((ref) {
  return FitnessCalendarController(ref)..restore();
});

class FitnessCalendarController extends StateNotifier<FitnessCalendarState> {
  FitnessCalendarController(this._ref) : super(const FitnessCalendarState());

  final Ref _ref;
  final _uuid = const Uuid();

  FitnessCalendarRepository get _calendar =>
      _ref.read(fitnessCalendarRepositoryProvider);
  PlanEnrollmentRepository get _enrollments =>
      _ref.read(planEnrollmentRepositoryProvider);

  Future<void> restore() async {
    final events = await _calendar.loadEvents();
    final enrollments = await _enrollments.load();
    state = FitnessCalendarState(
      events: events,
      enrollments: enrollments,
      ready: true,
    );
    await syncHistoryIntoCalendar();
  }

  Future<void> _persist() async {
    await _calendar.saveEvents(state.events);
    await _enrollments.save(state.enrollments);
  }

  /// Completed workouts become calendar entries automatically (no double log).
  Future<void> syncHistoryIntoCalendar() async {
    final history = _ref.read(workoutHistoryProvider).entries;
    if (history.isEmpty) return;
    final existingIds = state.events
        .map((e) => e.historyEntryId)
        .whereType<String>()
        .toSet();
    final additions = <FitnessCalendarEvent>[];
    for (final entry in history) {
      if (existingIds.contains(entry.id)) continue;
      additions.add(FitnessCalendarEvent.fromHistory(entry));
    }
    if (additions.isEmpty) return;
    state = state.copyWith(events: [...state.events, ...additions]);
    await _calendar.saveEvents(state.events);
  }

  Future<void> upsert(FitnessCalendarEvent event) async {
    final next = [...state.events];
    final index = next.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      next[index] = event;
    } else {
      next.add(event);
    }
    state = state.copyWith(events: next);
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.copyWith(
      events: state.events.where((e) => e.id != id).toList(),
    );
    await _persist();
  }

  Future<void> scheduleWorkout({
    required String title,
    required DateTime date,
    required FitnessEventKind kind,
    int? timeOfDayMinutes,
    int? durationMinutes,
    ReminderSettings reminder = const ReminderSettings(),
    String? routineId,
    String? gymId,
    String? notes,
  }) async {
    await upsert(
      FitnessCalendarEvent(
        id: _uuid.v4(),
        title: title,
        kind: kind,
        date: DateTime(date.year, date.month, date.day),
        timeOfDayMinutes: timeOfDayMinutes,
        durationMinutes: durationMinutes,
        reminder: reminder,
        routineId: routineId,
        gymId: gymId,
        notes: notes,
      ),
    );
  }

  Future<void> markRestDay(DateTime date, {String title = 'Rest'}) async {
    await scheduleWorkout(
      title: title,
      date: date,
      kind: FitnessEventKind.restDay,
    );
  }

  /// When a workout completes, mirror into calendar + sync port.
  Future<void> onWorkoutCompleted(WorkoutHistoryEntry entry) async {
    await upsert(FitnessCalendarEvent.fromHistory(entry));
    await _ref.read(fitnessSyncPortProvider).enqueueWorkout(entry);
  }

  Future<void> enrollPlan({
    required WorkoutPlan plan,
    required DateTime startDate,
    required List<int> trainingWeekdays,
    int? preferredTimeMinutes,
    ReminderSettings reminder = const ReminderSettings(),
    int weeksToSchedule = 0,
  }) async {
    final enrollment = PlanEnrollment(
      id: _uuid.v4(),
      planId: plan.id,
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      trainingWeekdays: trainingWeekdays,
      preferredTimeMinutes: preferredTimeMinutes,
      reminder: reminder,
    );
    state = state.copyWith(
      enrollments: [...state.enrollments, enrollment],
    );

    final weeks = weeksToSchedule > 0 ? weeksToSchedule : plan.weeks;
    final events = <FitnessCalendarEvent>[...state.events];
    for (var w = 0; w < weeks; w++) {
      for (final day in plan.weeklyStructure) {
        if (trainingWeekdays.isNotEmpty &&
            !day.isRest &&
            !trainingWeekdays.contains(day.weekday)) {
          continue;
        }
        final scheduled = _dateForPlanDay(
          start: enrollment.startDate,
          weekIndex: w,
          weekday: day.weekday,
        );
        if (scheduled.isBefore(enrollment.startDate)) continue;
        events.add(
          FitnessCalendarEvent(
            id: _uuid.v4(),
            title: day.title,
            kind: day.isRest
                ? FitnessEventKind.restDay
                : FitnessEventKind.scheduledWorkout,
            date: scheduled,
            timeOfDayMinutes: day.isRest ? null : preferredTimeMinutes,
            durationMinutes: day.isRest
                ? null
                : ((plan.durationMin + plan.durationMax) ~/ 2),
            reminder: reminder,
            planId: plan.id,
            routineId: day.routineId,
            notes: day.focus,
          ),
        );
      }
    }
    state = state.copyWith(events: events);
    await _persist();
  }

  DateTime _dateForPlanDay({
    required DateTime start,
    required int weekIndex,
    required int weekday,
  }) {
    final startMonday = DateTime(start.year, start.month, start.day)
        .subtract(Duration(days: start.weekday - 1));
    return startMonday.add(Duration(days: (weekIndex * 7) + (weekday - 1)));
  }

  Future<void> reschedule(String eventId, DateTime newDate) async {
    final event = state.events.where((e) => e.id == eventId).firstOrNull;
    if (event == null) return;
    await upsert(
      event.copyWith(
        date: DateTime(newDate.year, newDate.month, newDate.day),
      ),
    );
  }
}

/// Convenience: today's primary planned workout for device-free Today.
FitnessCalendarEvent? todaysPlanEvent(FitnessCalendarState calendar) {
  final today = DateTime.now();
  final dayEvents = calendar.forDay(today);
  for (final e in dayEvents) {
    if (e.isRest) continue;
    if (e.status == FitnessEventStatus.cancelled) continue;
    return e;
  }
  return null;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}

// Re-export plan lookup for UI
WorkoutPlan? planById(String id) => WorkoutPlanLibrary.byId(id);
