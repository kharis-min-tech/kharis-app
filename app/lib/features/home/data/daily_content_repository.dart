import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kharis_app/core/services/content_api.dart';

/// `YYYY-MM-DD` key for [date]'s calendar day, matching the Studio's `date`
/// columns.
String readingDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// One Studio Daily Reading or Daily Prayer entry.
@immutable
class DailyEntry {
  const DailyEntry({required this.title, this.body = '', this.reference = ''});

  final String title;

  /// Free text, or empty.
  final String body;

  /// Free-text scripture reference ("John 3:16-18"), or empty.
  final String reference;
}

/// Today's reading and prayer; at least one is set.
@immutable
class DailyContent {
  const DailyContent({this.reading, this.prayer});

  final DailyEntry? reading;

  /// No prayer means no prayer section.
  final DailyEntry? prayer;
}

/// Today's Studio Daily Message: a sermon, with the Studio's note.
@immutable
class DailyMessage {
  const DailyMessage({required this.sermonId, this.note = ''});

  final String sermonId;

  /// Free text, or empty.
  final String note;
}

/// Studio workspaces whose daily entries the app shows, most specific first:
/// the Mobile App workspace, then the shared one.
const List<String> kAppWorkspaces = ['app', 'general'];

/// Today's reading, prayer and message from the Content Studio (Supabase),
/// through [ContentApi] and its offline copy. Nothing is bundled: when the
/// Studio has nothing for today the streams emit `null` and the UI hides the
/// card.
///
/// - Reading and prayer: today's `daily_entries` rows of kind `reading` and
///   `prayer`, the `app` workspace's before the `general` one's.
/// - Message: today's `daily_messages` row, which names a sermon.
///
/// A table or column the Studio database does not have (yet) answers with a
/// 4xx; that reads as "nothing today", not as a failure.
class DailyContentRepository {
  DailyContentRepository({required this._api, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ContentApi _api;
  final DateTime Function() _clock;

  static const _entryTable = 'daily_entries';
  static const _messageTable = 'daily_messages';

  /// Today's reading and prayer, or `null` when there are neither. The saved
  /// copy first, then the network's; a network failure ends the stream
  /// quietly when the saved copy is on screen, and is an error otherwise.
  Stream<DailyContent?> watchTodaysContent() {
    final key = readingDateKey(_clock());
    return _todayRows(_entryTable, {
      'date': 'eq.$key',
      'workspace': 'in.(${kAppWorkspaces.join(',')})',
    }).map((rows) {
      final reading = _entry(rows, key, 'reading');
      final prayer = _entry(rows, key, 'prayer');
      if (reading == null && prayer == null) return null;
      return DailyContent(reading: reading, prayer: prayer);
    });
  }

  /// Today's Daily Message, or `null`.
  Stream<DailyMessage?> watchTodaysMessage() {
    final key = readingDateKey(_clock());
    return _todayRows(_messageTable, {'date': 'eq.$key'}).map((rows) {
      for (final row in rows) {
        final sermonId = _text(row['sermon_id']);
        if (_isDay(row, key) && sermonId != null) {
          return DailyMessage(
            sermonId: sermonId,
            note: _text(row['note']) ?? '',
          );
        }
      }
      return null;
    });
  }

  Stream<List<Map<String, dynamic>>> _todayRows(
    String table,
    Map<String, String> query,
  ) async* {
    final saved = _api.cached(table);
    if (saved != null) yield saved;
    try {
      yield await _api.fetch(table, query: query);
    } catch (error) {
      if (_isMissing(error)) {
        yield const [];
      } else if (saved == null) {
        rethrow;
      }
    }
  }

  /// The Studio answered, but rejected the query: the table or a column is
  /// not there. Server errors and dropped connections are real failures.
  static bool _isMissing(Object error) {
    final status = error is DioException ? error.response?.statusCode : null;
    return status != null && status >= 400 && status < 500;
  }

  /// Today's [kind] entry with a title, the app workspace's first.
  static DailyEntry? _entry(
    List<Map<String, dynamic>> rows,
    String key,
    String kind,
  ) {
    for (final workspace in kAppWorkspaces) {
      for (final row in rows) {
        final title = _text(row['title']);
        if (title == null ||
            row['kind'] != kind ||
            row['workspace'] != workspace ||
            !_isDay(row, key)) {
          continue;
        }
        return DailyEntry(
          title: title,
          body: _text(row['body']) ?? '',
          reference: _text(row['reference']) ?? '',
        );
      }
    }
    return null;
  }

  /// The saved copy of a date-filtered table may be from another day.
  static bool _isDay(Map<String, dynamic> row, String key) {
    final date = row['date'];
    return date is String && date.startsWith(key);
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
