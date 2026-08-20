import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/vytal_colors.dart';
import '../../core/theme/vytal_theme.dart';
import '../../domain/models/entitlements.dart';
import '../../domain/models/fitness_hub_models.dart';
import '../../fitness/calendar_controller.dart';
import '../../fitness/plan_library.dart';
import '../../subscription/monetization.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';
import '../shared/vytal_controls.dart';
import 'upgrade_prompts.dart';

class WorkoutPlansScreen extends ConsumerStatefulWidget {
  const WorkoutPlansScreen({super.key});

  @override
  ConsumerState<WorkoutPlansScreen> createState() => _WorkoutPlansScreenState();
}

class _WorkoutPlansScreenState extends ConsumerState<WorkoutPlansScreen> {
  PlanGoal? _goal;
  PlanDifficulty? _difficulty;
  WorkoutPlan? _detail;

  @override
  Widget build(BuildContext context) {
    if (_detail != null) {
      return _PlanDetailView(
        plan: _detail!,
        onBack: () => setState(() => _detail = null),
        onStart: () => _showStartSheet(_detail!),
      );
    }

    final plans = WorkoutPlanLibrary.all.where((p) {
      if (_goal != null && p.goal != _goal) return false;
      if (_difficulty != null && p.difficulty != _difficulty) return false;
      return true;
    }).toList();

    return SectionScaffold(
      title: 'Workout Plans',
      subtitle: 'Structured weeks — no outcome guarantees.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const VytalSectionHeader(title: 'Goal'),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _goal == null,
                    showCheckmark: false,
                    selectedColor: VytalColors.teal.withValues(alpha: 0.16),
                    onSelected: (_) => setState(() => _goal = null),
                  ),
                ),
                for (final goal in PlanGoal.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(goal.label),
                      selected: _goal == goal,
                      showCheckmark: false,
                      selectedColor: VytalColors.teal.withValues(alpha: 0.16),
                      onSelected: (_) => setState(() => _goal = goal),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          VytalTabSelector<PlanDifficulty?>(
            values: const [null, ...PlanDifficulty.values],
            selected: _difficulty,
            labelOf: (d) => d?.label ?? 'All levels',
            onChanged: (d) => setState(() => _difficulty = d),
          ),
          const SizedBox(height: 16),
          if (plans.isEmpty)
            GlassPanel(
              child: Text(
                'No plans match these filters.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (final plan in plans) ...[
              _PlanCard(
                plan: plan,
                onTap: () => setState(() => _detail = plan),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _showStartSheet(WorkoutPlan plan) async {
    final monetization = ref.read(monetizationProvider);
    if (WorkoutPlanLibrary.requiresPro(plan) &&
        !monetization.canUseFeature(EntitlementKeys.plansAdvanced)) {
      await ContextualUpgradeSheet.show(
        context,
        title: plan.name,
        entitlementKey: EntitlementKeys.plansAdvanced,
        entitlementHint: 'PRO plan · Vytal Pro helps you train smarter',
        bullets: const [
          'Advanced multi-week programming',
          'Goal-specific and adaptive structures',
          'Smarter scheduling into your calendar',
        ],
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StartPlanSheet(plan: plan),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onTap});

  final WorkoutPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  StatusPill(
                    label: plan.advanced ? 'PRO' : plan.difficulty.label,
                    emphasis: plan.advanced,
                  ),
                ],
              ),
              if (plan.tagline != null) ...[
                const SizedBox(height: 4),
                Text(
                  plan.tagline!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: extras.textMuted),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatusPill(label: plan.goal.label),
                  StatusPill(label: '${plan.weeks} wk'),
                  StatusPill(label: '${plan.daysPerWeek} d/wk'),
                  StatusPill(label: plan.durationLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanDetailView extends StatelessWidget {
  const _PlanDetailView({
    required this.plan,
    required this.onBack,
    required this.onStart,
  });

  final WorkoutPlan plan;
  final VoidCallback onBack;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SectionScaffold(
      title: plan.name,
      subtitle: plan.tagline,
      actions: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (plan.advanced)
                      const StatusPill(label: 'PRO', emphasis: true),
                    StatusPill(label: plan.goal.label, emphasis: true),
                    StatusPill(label: plan.difficulty.label),
                    StatusPill(label: '${plan.weeks} weeks'),
                    StatusPill(label: plan.durationLabel),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Equipment: ${plan.equipment.join(' · ')}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: extras.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const VytalSectionHeader(
            title: 'Weekly structure',
            subtitle: 'Typical week — adjust days when you start.',
          ),
          for (final day in plan.weeklyStructure) ...[
            GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      weekdays[day.weekday - 1],
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day.title,
                            style: Theme.of(context).textTheme.titleSmall),
                        if (day.focus != null)
                          Text(
                            day.focus!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: extras.textMuted),
                          ),
                      ],
                    ),
                  ),
                  if (day.isRest)
                    const StatusPill(label: 'Rest')
                  else if (day.optional)
                    const StatusPill(label: 'Optional'),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onStart,
            child: Text(plan.advanced ? 'Start Plan · PRO' : 'Start Plan'),
          ),
        ],
      ),
    );
  }
}

class _StartPlanSheet extends ConsumerStatefulWidget {
  const _StartPlanSheet({required this.plan});

  final WorkoutPlan plan;

  @override
  ConsumerState<_StartPlanSheet> createState() => _StartPlanSheetState();
}

class _StartPlanSheetState extends ConsumerState<_StartPlanSheet> {
  late DateTime _startDate;
  late Set<int> _trainingDays;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  var _reminder = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _trainingDays = widget.plan.weeklyStructure
        .where((d) => !d.isRest)
        .map((d) => d.weekday)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.vytalExtras;
    final theme = Theme.of(context);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
            Text('Start ${widget.plan.name}', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(
                '${_startDate.year}-${_startDate.month}-${_startDate.day}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            Text('Training days', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 1; i <= 7; i++)
                  FilterChip(
                    label: Text(labels[i - 1]),
                    selected: _trainingDays.contains(i),
                    showCheckmark: false,
                    selectedColor: VytalColors.teal.withValues(alpha: 0.16),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _trainingDays.add(i);
                      } else {
                        _trainingDays.remove(i);
                      }
                    }),
                  ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Preferred time'),
              subtitle: Text(_time.format(context)),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: () async {
                final picked =
                    await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder'),
              value: _reminder,
              onChanged: (v) => setState(() => _reminder = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _trainingDays.isEmpty ? null : _enroll,
              child: const Text('Enroll & schedule'),
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

  Future<void> _enroll() async {
    await ref.read(fitnessCalendarProvider.notifier).enrollPlan(
          plan: widget.plan,
          startDate: _startDate,
          trainingWeekdays: _trainingDays.toList()..sort(),
          preferredTimeMinutes: _time.hour * 60 + _time.minute,
          reminder: ReminderSettings(enabled: _reminder),
        );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.plan.name} added to your calendar')),
    );
  }
}
