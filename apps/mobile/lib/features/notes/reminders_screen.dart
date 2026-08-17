import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions/permission_catalog.dart';
import '../../core/permissions/permission_prompt.dart';
import '../../domain/models/notes_models.dart';
import '../../notes/notes_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  final _title = TextEditingController();
  DateTime _when = DateTime.now().add(const Duration(hours: 2));
  String _category = ReminderCategories.custom;
  String _repeat = 'none';
  bool _notify = true;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    var notify = _notify;
    if (notify) {
      final granted = await ensureVytalPermission(
        context: context,
        ref: ref,
        item: PermissionCatalog.notifications,
        headline: 'Allow reminder notifications?',
        explanation:
            'Vytal can alert you when a reminder is due. This is requested only when you turn notifications on.',
      );
      if (!granted) {
        notify = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Reminder saved without OS notifications. Enable them in Settings → Permissions anytime.',
              ),
            ),
          );
        }
      }
    }
    await ref.read(notesProvider.notifier).addReminder(
          title: _title.text,
          when: _when,
          category: _category,
          repeat: _repeat,
          notify: notify,
        );
    _title.clear();
    if (!mounted) return;
    if (notify) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder saved. Notification permission is enabled.'),
        ),
      );
    } else if (!_notify) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder saved without notification.')),
      );
    }
    setState(() => _notify = notify);
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(notesProvider).reminders;
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Reminders',
      subtitle: 'Local alerts until OS push is enabled.',
      child: Column(
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    hintText: 'Stretch, hydrate, wind-down…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final cat in ReminderCategories.all)
                      ChoiceChip(
                        label: Text(ReminderCategories.label(cat)),
                        selected: _category == cat,
                        onSelected: (_) => setState(() => _category = cat),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final repeat in const ['none', 'daily', 'weekly'])
                      ChoiceChip(
                        label: Text(repeat),
                        selected: _repeat == repeat,
                        onSelected: (_) => setState(() => _repeat = repeat),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Notification'),
                  value: _notify,
                  onChanged: (v) async {
                    if (!v) {
                      setState(() => _notify = false);
                      return;
                    }
                    final granted = await ensureVytalPermission(
                      context: context,
                      ref: ref,
                      item: PermissionCatalog.notifications,
                      headline: 'Allow reminder notifications?',
                      explanation:
                          'Turn this on so Vytal can remind you at the time you pick.',
                    );
                    if (!mounted) return;
                    setState(() => _notify = granted);
                  },
                ),
                TextButton(
                  onPressed: _pickWhen,
                  child: Text('When ${_format(_when.toUtc())}'),
                ),
                FilledButton(
                  onPressed: _add,
                  child: const Text('Add reminder'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (reminders.isEmpty)
            const EmptyMetricCard(
              title: 'No reminders',
              message: 'Create a reminder to nudge habits.',
            )
          else
            ...reminders.map(
              (reminder) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassPanel(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Checkbox(
                          value: reminder.done,
                          onChanged: (_) => ref
                              .read(notesProvider.notifier)
                              .toggleReminder(reminder.id),
                        ),
                        title: Text(
                          reminder.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration: reminder.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          '${ReminderCategories.label(reminder.category)} · '
                          '${reminder.repeat} · ${_format(reminder.when)}',
                        ),
                        trailing: IconButton(
                          onPressed: () => ref
                              .read(notesProvider.notifier)
                              .deleteReminder(reminder.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => ref
                              .read(notesProvider.notifier)
                              .snoozeReminder(reminder.id),
                          child: const Text('Snooze 10 min'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _format(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
