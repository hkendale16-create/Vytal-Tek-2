import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/notes_models.dart';
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
  final _search = TextEditingController();
  String _category = NoteCategories.general;
  DateTime _date = DateTime.now();
  String? _editingId;

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_editingId != null) {
      await ref.read(notesProvider.notifier).updateNote(
            _editingId!,
            body: _controller.text,
            category: _category,
            attachedDate: _date,
          );
      _editingId = null;
    } else {
      await ref.read(notesProvider.notifier).addNote(
            _controller.text,
            category: _category,
            attachedDate: _date,
            tags: [_category],
          );
    }
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider).notes;
    final query = _search.text.trim().toLowerCase();
    final filtered = notes.where((n) {
      final matchesQuery =
          query.isEmpty || n.body.toLowerCase().contains(query);
      final matchesCat =
          _category == NoteCategories.general || n.category == _category;
      return matchesQuery && matchesCat;
    }).toList();
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
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search notes',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final cat in NoteCategories.all)
                ChoiceChip(
                  label: Text(NoteCategories.label(cat)),
                  selected: _category == cat,
                  onSelected: (_) => setState(() => _category = cat),
                ),
            ],
          ),
          const SizedBox(height: 10),
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
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Text(
                    'Date ${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                  ),
                ),
                FilledButton(
                  onPressed: _save,
                  child: Text(_editingId == null ? 'Save note' : 'Update note'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const EmptyMetricCard(
              title: 'No notes',
              message: 'Add a note to track how you feel.',
            )
          else
            ...filtered.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.body, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      Text(
                        '${NoteCategories.label(note.category)} · ${_format(note.createdAt)}',
                        style: theme.textTheme.labelSmall,
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              _controller.text = note.body;
                              _category = note.category;
                              _editingId = note.id;
                              setState(() {});
                            },
                            child: const Text('Edit'),
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
