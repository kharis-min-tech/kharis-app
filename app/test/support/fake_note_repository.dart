import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kharis_app/features/notes/data/note_repository.dart';

/// Records notepad saves and deletes without touching a store, so the notes
/// stream a test feeds stays exactly as the test set it.
class FakeNoteRepository implements NoteRepository {
  final List<Note> saved = [];
  final List<String> retired = [];
  final List<String> deleted = [];

  @override
  String newId() => 'pad-${saved.length}';

  @override
  Future<void> saveNotepad(
    Note pad, {
    Iterable<String> replaces = const [],
  }) async {
    saved.add(pad);
    retired.addAll(replaces);
  }

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Taps the first character of the notepad — where tests put a stamp.
Future<void> tapFirstStamp(WidgetTester tester) => tester.tapAt(
  tester.getTopLeft(find.byType(EditableText)) + const Offset(8, 8),
);
