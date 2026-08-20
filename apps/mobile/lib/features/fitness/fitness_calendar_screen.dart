import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/fitness_hub_models.dart';
import '../../domain/models/workout_models.dart';
import '../../fitness/calendar_controller.dart';
import '../../workouts/workout_controllers.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../shared/vytal_controls.dart';

enum _CalendarMode { week, month }

const _weekdayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

class FitnessCalendarScreen extends ConsumerStatefulWidget {
  const FitnessCalendarScreen({super.key});

  @override
  ConsumerState<FitnessCalendarScreen> createState() =>
      _FitnessCalendarScreenState();
}

class _FitnessCalendarScreenState extends ConsumerState<FitnessCalendarScreen> {
  var _mode = _CalendarMode.week;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStart =>
      _anchor.subtract(Duration(days: _anchor.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final calendar = ref.watch(fitnessCalendarProvider);
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Calendar',
      subtitle: 'Plan sessions and rest — history syncs automatically.',
      actions: [
        IconButton(
          tooltip: 'Previous',
          onPressed: () => setState(() {
            _anchor = _mode == _CalendarMode.week
                ? _anchor.subtract(const Duration(days: 7))
                : DateTime(_anchor.year, _anchor.month - 1, 1);
          }),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next',
          onPressed: () => setState(() {
            _anchor = _mode == _CalendarMode.week
                ? _anchor.add(const Duration(days: 7))
                : DateTime(_anchor.year, _anchor.month + 1, 1);
          }),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VytalTabSelector<_CalendarMode>(
            values: _CalendarMode.values,
            selected: _mode,
            labelOf: (m) => m == _CalendarMode.week ? 'Week' : 'Month',
            onChanged: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 14),
          Text(
            _mode == _CalendarMode.week
                ? _weekRangeLabel(_weekStart)
                : _monthLabel(_anchor),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (!calendar.ready)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_mode == _CalendarMode.week)
            _WeekView(
              weekStart: _weekStart,
              calendar: calendar,
              onDayTap: _openScheduleSheet,
            )
          else
            _MonthView(
              month: DateTime(_anchor.year, _anchor.month),
              calendar: calendar,
              onDayTap: _openScheduleSheet,
            ),
        ],
      ),
    );
  }

  Future<void> _openScheduleSheet(DateTime day) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScheduleWorkoutSheet(initialDate: day),
    );
  }

  String _weekRangeLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    return '${_shortDate(start)} – ${_shortDate(end)}';
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _shortDate(DateTime d) => '${d.month}/${d.day}';
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.weekStart,
    required this.calendar,
    required this.onDayTap,
  });

  final DateTime weekStart;
  final FitnessCalendarState calendar;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return Column(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final day = weekStart.add(Duration(days: i));
              final events = calendar.forDay(day);
              final isToday = day == todayKey;
              final primary = events.isEmpty ? null : events.first;
              final label = primary?.title ?? 'Open';
              final done = primary?.isCompleted == true;
              final rest = primary?.isRest == true;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onDayTap(day),
                  child: GlassPanel(
                    glow: isToday,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            _weekdayLabels[i],
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isToday
                                      ? VytalColors.teal
                                      : null,
                                ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (isToday)
                          const StatusPill(label: 'Today', emphasis: true)
                        else if (done)
                          const Icon(
                            Icons.check_circle,
                            color: VytalColors.teal,
                            size: 20,
                          )
                        else if (rest)
                          StatusPill(label: 'Rest')
                        else if (primary != null)
                          StatusPill(label: primary.kind.label),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.calendar,
    required this.onDayTap,
  });

  final DateTime month;
  final FitnessCalendarState calendar;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return GlassPanel(
      child: Column(
        children: [
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      label.substring(0, 1),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: extras.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: leading + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final dayNum = index - leading + 1;
              final day = DateTime(month.year, month.month, dayNum);
              final events = calendar.forDay(day);
              final isToday = day == todayKey;
              final hasEvent = events.isNotEmpty;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onDayTap(day),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isToday
                        ? VytalColors.teal.withValues(alpha: 0.14)
                        : null,
                    border: Border.all(
                      color: isToday
                          ? VytalColors.teal.withValues(alpha: 0.4)
                          : extras.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: isToday ? VytalColors.teal : null,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (hasEvent)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: VytalColors.teal,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

enum _ScheduleKind {
  existing,
  quick,
  cardio,
  strength,
  calisthenics,
  rest,
  custom,
}

extension on _ScheduleKind {
  String get label => switch (this) {
        _ScheduleKind.existing => 'Existing Workout',
        _ScheduleKind.quick => 'Quick',
        _ScheduleKind.cardio => 'Cardio',
        _ScheduleKind.strength => 'Strength',
        _ScheduleKind.calisthenics => 'Calisthenics',
        _ScheduleKind.rest => 'Rest',
        _ScheduleKind.custom => 'Custom',
      };

  FitnessEventKind get eventKind => switch (this) {
        _ScheduleKind.existing ||
        _ScheduleKind.quick =>
          FitnessEventKind.scheduledWorkout,
        _ScheduleKind.cardio => FitnessEventKind.cardio,
        _ScheduleKind.strength => FitnessEventKind.strength,
        _ScheduleKind.calisthenics => FitnessEventKind.calisthenics,
        _ScheduleKind.rest => FitnessEventKind.restDay,
        _ScheduleKind.custom => FitnessEventKind.custom,
      };
}

class _ScheduleWorkoutSheet extends ConsumerStatefulWidget {
  const _ScheduleWorkoutSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  ConsumerState<_ScheduleWorkoutSheet> createState() =>
      _ScheduleWorkoutSheetState();
}

class _ScheduleWorkoutSheetState extends ConsumerState<_ScheduleWorkoutSheet> {
  late DateTime _date;
  var _kind = _ScheduleKind.quick;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  var _duration = 45;
  var _reminder = false;
  final _notes = TextEditingController();
  final _title = TextEditingController(text: 'Workout');
  WorkoutRoutine? _routine;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _notes.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final library = ref.watch(workoutLibraryProvider);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: extras.elevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: extras.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Schedule Workout', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in _ScheduleKind.values)
                  ChoiceChip(
                    label: Text(kind.label),
                    selected: _kind == kind,
                    showCheckmark: false,
                    selectedColor: VytalColors.teal.withValues(alpha: 0.16),
                    onSelected: (_) => setState(() {
                      _kind = kind;
                      if (kind == _ScheduleKind.rest) {
                        _title.text = 'Rest';
                      } else if (kind != _ScheduleKind.existing &&
                          kind != _ScheduleKind.custom) {
                        _title.text = kind.label;
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_kind == _ScheduleKind.existing) ...[
              DropdownButtonFormField<WorkoutRoutine>(
                initialValue: _routine,
                decoration: const InputDecoration(labelText: 'Routine'),
                items: [
                  for (final r in library.routines)
                    DropdownMenuItem(value: r, child: Text(r.name)),
                ],
                onChanged: (r) => setState(() {
                  _routine = r;
                  if (r != null) _title.text = r.name;
                }),
              ),
              const SizedBox(height: 10),
            ],
            if (_kind == _ScheduleKind.custom ||
                _kind == _ScheduleKind.quick ||
                _kind == _ScheduleKind.existing)
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text('${_date.year}-${_date.month}-${_date.day}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            if (_kind != _ScheduleKind.rest) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Time'),
                subtitle: Text(_time.format(context)),
                trailing: const Icon(Icons.schedule_outlined),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) setState(() => _time = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Duration'),
                subtitle: Text('$_duration min'),
                trailing: SizedBox(
                  width: 140,
                  child: Slider(
                    value: _duration.toDouble(),
                    min: 15,
                    max: 120,
                    divisions: 21,
                    label: '$_duration min',
                    onChanged: (v) => setState(() => _duration = v.round()),
                  ),
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder'),
              subtitle: const Text('Notify 30 minutes before'),
              value: _reminder,
              onChanged: (v) => setState(() => _reminder = v),
            ),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Save to calendar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim().isEmpty ? _kind.label : _title.text.trim();
    await ref.read(fitnessCalendarProvider.notifier).scheduleWorkout(
          title: title,
          date: _date,
          kind: _kind.eventKind,
          timeOfDayMinutes: _kind == _ScheduleKind.rest
              ? null
              : _time.hour * 60 + _time.minute,
          durationMinutes: _kind == _ScheduleKind.rest ? null : _duration,
          reminder: ReminderSettings(enabled: _reminder),
          routineId: _routine?.id,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
    if (!mounted) return;
    Navigator.pop(context);
  }
}
