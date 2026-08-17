import 'package:uuid/uuid.dart';

class VytalNote {
  const VytalNote({
    required this.id,
    required this.body,
    required this.createdAt,
    this.updatedAt,
    this.tags = const [],
    this.category = 'general',
    this.attachedDate,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> tags;
  final String category;
  final DateTime? attachedDate;

  VytalNote copyWith({
    String? body,
    DateTime? updatedAt,
    List<String>? tags,
    String? category,
    DateTime? attachedDate,
  }) {
    return VytalNote(
      id: id,
      body: body ?? this.body,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      attachedDate: attachedDate ?? this.attachedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'tags': tags,
        'category': category,
        'attachedDate': attachedDate?.toIso8601String(),
      };

  factory VytalNote.fromJson(Map<String, dynamic> json) => VytalNote(
        id: json['id'] as String? ?? const Uuid().v4(),
        body: json['body'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        category: json['category'] as String? ?? 'general',
        attachedDate: DateTime.tryParse(json['attachedDate'] as String? ?? ''),
      );
}

abstract final class NoteCategories {
  static const general = 'general';
  static const workout = 'workout';
  static const sleep = 'sleep';
  static const recovery = 'recovery';
  static const health = 'health';

  static const all = [general, workout, sleep, recovery, health];

  static String label(String key) => switch (key) {
        workout => 'Workout',
        sleep => 'Sleep',
        recovery => 'Recovery',
        health => 'Health reading',
        _ => 'General day',
      };
}

class VytalReminder {
  const VytalReminder({
    required this.id,
    required this.title,
    required this.when,
    required this.createdAt,
    this.done = false,
    this.noteId,
    this.category = 'custom',
    this.repeat = 'none',
    this.notify = true,
  });

  final String id;
  final String title;
  final DateTime when;
  final DateTime createdAt;
  final bool done;
  final String? noteId;
  final String category;
  final String repeat;
  final bool notify;

  VytalReminder copyWith({
    String? title,
    DateTime? when,
    bool? done,
    String? noteId,
    String? category,
    String? repeat,
    bool? notify,
  }) {
    return VytalReminder(
      id: id,
      title: title ?? this.title,
      when: when ?? this.when,
      createdAt: createdAt,
      done: done ?? this.done,
      noteId: noteId ?? this.noteId,
      category: category ?? this.category,
      repeat: repeat ?? this.repeat,
      notify: notify ?? this.notify,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'when': when.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'done': done,
        'noteId': noteId,
        'category': category,
        'repeat': repeat,
        'notify': notify,
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
        category: json['category'] as String? ?? 'custom',
        repeat: json['repeat'] as String? ?? 'none',
        notify: json['notify'] as bool? ?? true,
      );
}

abstract final class ReminderCategories {
  static const workout = 'workout';
  static const hydration = 'hydration';
  static const bedtime = 'bedtime';
  static const charge = 'charge';
  static const custom = 'custom';

  static const all = [workout, hydration, bedtime, charge, custom];

  static String label(String key) => switch (key) {
        workout => 'Workout',
        hydration => 'Hydration',
        bedtime => 'Bedtime',
        charge => 'Charge wearable',
        _ => 'Custom',
      };
}
