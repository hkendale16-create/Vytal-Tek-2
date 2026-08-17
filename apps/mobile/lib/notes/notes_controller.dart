import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/notes_models.dart';

const _notesKey = 'vytal.notes.v1';
const _remindersKey = 'vytal.reminders.v1';

class NotesState {
  const NotesState({
    required this.notes,
    required this.reminders,
  });

  final List<VytalNote> notes;
  final List<VytalReminder> reminders;

  NotesState copyWith({
    List<VytalNote>? notes,
    List<VytalReminder>? reminders,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      reminders: reminders ?? this.reminders,
    );
  }
}

final notesProvider =
    StateNotifierProvider<NotesController, NotesState>((ref) {
  return NotesController()..restore();
});

class NotesController extends StateNotifier<NotesState> {
  NotesController()
      : super(const NotesState(notes: [], reminders: []));

  final _uuid = const Uuid();

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final notesRaw = prefs.getString(_notesKey);
      final remindersRaw = prefs.getString(_remindersKey);
      final notes = notesRaw == null
          ? <VytalNote>[]
          : (jsonDecode(notesRaw) as List)
              .cast<Map<String, dynamic>>()
              .map(VytalNote.fromJson)
              .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final reminders = remindersRaw == null
          ? <VytalReminder>[]
          : (jsonDecode(remindersRaw) as List)
              .cast<Map<String, dynamic>>()
              .map(VytalReminder.fromJson)
              .toList()
        ..sort((a, b) => a.when.compareTo(b.when));
      state = NotesState(notes: notes, reminders: reminders);
    } catch (_) {
      state = const NotesState(notes: [], reminders: []);
    }
  }

  Future<void> addNote(String body, {List<String> tags = const []}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final note = VytalNote(
      id: _uuid.v4(),
      body: trimmed,
      createdAt: DateTime.now().toUtc(),
      tags: tags,
    );
    state = state.copyWith(notes: [note, ...state.notes]);
    await _persist();
  }

  Future<void> deleteNote(String id) async {
    state = state.copyWith(
      notes: state.notes.where((n) => n.id != id).toList(),
      reminders: state.reminders
          .map((r) => r.noteId == id ? r.copyWith(noteId: null) : r)
          .toList(),
    );
    await _persist();
  }

  Future<void> addReminder({
    required String title,
    required DateTime when,
    String? noteId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final reminder = VytalReminder(
      id: _uuid.v4(),
      title: trimmed,
      when: when.toUtc(),
      createdAt: DateTime.now().toUtc(),
      noteId: noteId,
    );
    state = state.copyWith(
      reminders: [...state.reminders, reminder]
        ..sort((a, b) => a.when.compareTo(b.when)),
    );
    await _persist();
  }

  Future<void> toggleReminder(String id) async {
    state = state.copyWith(
      reminders: state.reminders
          .map((r) => r.id == id ? r.copyWith(done: !r.done) : r)
          .toList(),
    );
    await _persist();
  }

  Future<void> deleteReminder(String id) async {
    state = state.copyWith(
      reminders: state.reminders.where((r) => r.id != id).toList(),
    );
    await _persist();
  }

  /// Snippets safe for Coach Vital context (user-entered only).
  List<String> aiContextSnippets({int limit = 5}) {
    return state.notes
        .take(limit)
        .map((n) => n.body.trim())
        .where((b) => b.isNotEmpty)
        .toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notesKey,
      jsonEncode(state.notes.map((n) => n.toJson()).toList()),
    );
    await prefs.setString(
      _remindersKey,
      jsonEncode(state.reminders.map((r) => r.toJson()).toList()),
    );
  }
}
