import 'package:uuid/uuid.dart';

class VytalNote {
  const VytalNote({
    required this.id,
    required this.body,
    required this.createdAt,
    this.updatedAt,
    this.tags = const [],
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> tags;

  VytalNote copyWith({
    String? body,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return VytalNote(
      id: id,
      body: body ?? this.body,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'tags': tags,
      };

  factory VytalNote.fromJson(Map<String, dynamic> json) => VytalNote(
        id: json['id'] as String? ?? const Uuid().v4(),
        body: json['body'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
      );
}

class VytalReminder {
  const VytalReminder({
    required this.id,
    required this.title,
    required this.when,
    required this.createdAt,
    this.done = false,
    this.noteId,
  });

  final String id;
  final String title;
  final DateTime when;
  final DateTime createdAt;
  final bool done;
  final String? noteId;

  VytalReminder copyWith({
    String? title,
    DateTime? when,
    bool? done,
    String? noteId,
  }) {
    return VytalReminder(
      id: id,
      title: title ?? this.title,
      when: when ?? this.when,
      createdAt: createdAt,
      done: done ?? this.done,
      noteId: noteId ?? this.noteId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'when': when.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'done': done,
        'noteId': noteId,
      };

  factory VytalReminder.fromJson(Map<String, dynamic> json) => VytalReminder(
        id: json['id'] as String? ?? const Uuid().v4(),
        title: json['title'] as String? ?? '',
        when: DateTime.tryParse(json['when'] as String? ?? '') ??
            DateTime.now().toUtc(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        done: json['done'] as bool? ?? false,
        noteId: json['noteId'] as String?,
      );
}
