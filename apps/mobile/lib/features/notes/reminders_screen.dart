import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final when = DateTime.now().toUtc().add(const Duration(hours: 2));
    await ref.read(notesProvider.notifier).addReminder(
          title: _title.text,
          when: when,
        );
    _title.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reminder saved for ~2 hours from now (local).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(notesProvider).reminders;
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Reminders',
      subtitle: 'Lightweight local reminders — system notifications come later.',
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
              message: 'Create a reminder to nudge habits. OS push arrives later.',
            )
          else
            ...reminders.map(
              (reminder) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassPanel(
                  child: ListTile(
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
                    subtitle: Text(_format(reminder.when)),
                    trailing: IconButton(
                      onPressed: () => ref
                          .read(notesProvider.notifier)
                          .deleteReminder(reminder.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
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
