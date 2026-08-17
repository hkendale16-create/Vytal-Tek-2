import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/notes_models.dart';
import '../../notes/notes_controller.dart';
import '../shared/health_ui.dart';
import '../shared/ui_primitives.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key, this.initialCategory, this.attachedRecordId});

  final String? initialCategory;
  final String? attachedRecordId;

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _controller = TextEditingController();
  final _search = TextEditingController();
  String _filter = NoteCategories.allFilter;
  String _composeCategory = NoteCategories.general;
  DateTime _date = DateTime.now();
  String? _editingId;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _composeCategory = widget.initialCategory!;
      _filter = widget.initialCategory!;
    }
  }

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
            category: _composeCategory,
            attachedDate: _date,
            attachedRecordId: widget.attachedRecordId,
            attachedRecordType: widget.initialCategory,
          );
      _editingId = null;
    } else {
      await ref.read(notesProvider.notifier).addNote(
            _controller.text,
            category: _composeCategory,
            attachedDate: _date,
            tags: [_composeCategory],
            attachedRecordId: widget.attachedRecordId,
            attachedRecordType: widget.initialCategory,
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
          _filter == NoteCategories.allFilter || n.category == _filter;
      return matchesQuery && matchesCat;
    }).toList();
    final theme = Theme.of(context);

    return SectionScaffold(
      title: 'Notes',
      subtitle: 'Your words for Coach Vital — never treated as sensor data.',
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Filter', style: theme.textTheme.labelLarge),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final cat in NoteCategories.filters)
                ChoiceChip(
                  label: Text(NoteCategories.label(cat)),
                  selected: _filter == cat,
                  onSelected: (_) => setState(() => _filter = cat),
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
                    hintText:
                        'Left shoulder felt tight today. Slept poorly. Had caffeine late.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Attach to', style: theme.textTheme.labelLarge),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final cat in NoteCategories.all)
                      ChoiceChip(
                        label: Text(NoteCategories.label(cat)),
                        selected: _composeCategory == cat,
                        onSelected: (_) =>
                            setState(() => _composeCategory = cat),
                      ),
                  ],
                ),
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
                  child:
                      Text(_editingId == null ? 'Save note' : 'Update note'),
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
                        [
                          NoteCategories.label(note.category),
                          _format(note.attachedDate ?? note.createdAt),
                          if (note.attachedRecordType != null)
                            'linked ${note.attachedRecordType}',
                        ].join(' · '),
                        style: theme.textTheme.labelSmall,
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              _controller.text = note.body;
                              _composeCategory = note.category;
                              _editingId = note.id;
                              if (note.attachedDate != null) {
                                _date = note.attachedDate!;
                              }
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
