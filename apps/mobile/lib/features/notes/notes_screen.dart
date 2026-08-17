import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../notes/notes_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    await ref.read(notesProvider.notifier).addNote(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider).notes;
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Notes',
      subtitle: 'User-entered context for Coach Vital — never treated as sensor data.',
      actions: [
        IconButton(
          tooltip: 'Reminders',
          onPressed: () => context.push('/reminders'),
          icon: const Icon(Icons.alarm_outlined),
        ),
      ],
      child: Column(
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'How did training feel? Sleep? Stress?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _add,
                  child: const Text('Save note'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            const EmptyMetricCard(
              title: 'No notes yet',
              message:
                  'Notes stay on-device for now and can inform Coach Vital without inventing vitals.',
            )
          else
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.body, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _format(note.createdAt),
                            style: theme.textTheme.labelSmall,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => ref
                                .read(notesProvider.notifier)
                                .deleteNote(note.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
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
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
