import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class Note {
  const Note({
    required this.id,
    this.sermonId,
    this.sermonTitle,
    this.positionMs,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? sermonId;
  final String? sermonTitle;
  final int? positionMs;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sermonId': sermonId,
        'sermonTitle': sermonTitle,
        'positionMs': positionMs,
        'text': text,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as String,
        sermonId: map['sermonId'] as String?,
        sermonTitle: map['sermonTitle'] as String?,
        positionMs: map['positionMs'] as int?,
        text: map['text'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );

  Note copyWith({
    String? id,
    String? sermonId,
    String? sermonTitle,
    int? positionMs,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Note(
        id: id ?? this.id,
        sermonId: sermonId ?? this.sermonId,
        sermonTitle: sermonTitle ?? this.sermonTitle,
        positionMs: positionMs ?? this.positionMs,
        text: text ?? this.text,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class NoteRepository {
  NoteRepository(this._box);

  final Box<dynamic> _box;

  static String generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  List<Note> list() {
    final notes = _box.values
        .map((raw) {
          try {
            final map = Map<String, dynamic>.from(
              jsonDecode(raw as String) as Map,
            );
            return Note.fromMap(map);
          } catch (_) {
            return null;
          }
        })
        .whereType<Note>()
        .toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  Note? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    try {
      final map =
          Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
      return Note.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsert(Note note) async {
    await _box.put(note.id, jsonEncode(note.toMap()));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
