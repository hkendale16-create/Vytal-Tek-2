import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/entitlements.dart';
import '../../notes/notes_controller.dart';
import '../../state/app_session_controller.dart';
import '../today/today_health_provider.dart';
import 'coach_vital_engine.dart';

const _chatKey = 'vytal.coach.chat.v1';

class CoachChatState {
  const CoachChatState({
    required this.messages,
    required this.isThinking,
  });

  final List<CoachMessage> messages;
  final bool isThinking;

  CoachChatState copyWith({
    List<CoachMessage>? messages,
    bool? isThinking,
  }) {
    return CoachChatState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
    );
  }
}

final coachChatProvider =
    StateNotifierProvider<CoachChatController, CoachChatState>((ref) {
  return CoachChatController(ref)..restore();
});

class CoachChatController extends StateNotifier<CoachChatState> {
  CoachChatController(this._ref)
      : super(const CoachChatState(messages: [], isThinking: false));

  final Ref _ref;
  final _engine = const CoachVitalEngine();
  final _uuid = const Uuid();

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chatKey);
    final session = _ref.read(appSessionProvider);
    final notes = _ref.read(notesProvider).notes;

    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .map(CoachMessage.fromJson)
            .toList();
        if (list.isNotEmpty) {
          state = state.copyWith(messages: list);
          return;
        }
      } catch (_) {
        // Fall through to welcome.
      }
    }

    final welcome = CoachMessage(
      id: _uuid.v4(),
      fromCoach: true,
      text: _engine.welcome(
        mode: session.operatingMode,
        hasNotes: notes.isNotEmpty,
      ),
      at: DateTime.now().toUtc(),
    );
    state = state.copyWith(messages: [welcome]);
    await _persist();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final session = _ref.read(appSessionProvider);
    if (!session.entitlements.canUse(EntitlementKeys.aiBasic)) return;

    final user = CoachMessage(
      id: _uuid.v4(),
      fromCoach: false,
      text: trimmed,
      at: DateTime.now().toUtc(),
    );
    state = state.copyWith(
      messages: [...state.messages, user],
      isThinking: true,
    );
    await _persist();

    final health = _ref.read(todayHealthProvider).valueOrNull;
    final notes = _ref.read(notesProvider).notes;
    final snippets = notes
        .take(5)
        .map((n) => n.body.trim())
        .where((b) => b.isNotEmpty)
        .map((b) => b.length > 80 ? '${b.substring(0, 80)}…' : b)
        .toList();

    final replyText = _engine.reply(
      userText: trimmed,
      session: session,
      health: health,
      recentNoteSnippets: snippets,
      advanced: session.entitlements.canUse(EntitlementKeys.aiAdvanced),
    );

    final reply = CoachMessage(
      id: _uuid.v4(),
      fromCoach: true,
      text: replyText,
      at: DateTime.now().toUtc(),
    );
    state = state.copyWith(
      messages: [...state.messages, reply],
      isThinking: false,
    );
    await _persist();
  }

  Future<void> clear() async {
    state = const CoachChatState(messages: [], isThinking: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatKey);
    await restore();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(state.messages.map((m) => m.toJson()).toList());
    await prefs.setString(_chatKey, encoded);
  }
}
